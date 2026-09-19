//! CLI validator and conformance runner for the Gateworlds world protocol.
//!
//! Usage:
//!   gateworlds-validate conformance <dir>    run every vector under <dir>
//!   gateworlds-validate package <dir>...     validate world package directories
//!   gateworlds-validate doc <kind> <file>    validate one document (world|items|save)

use gateworlds_validate::publish;

use std::path::Path;
use std::process::ExitCode;

use gateworlds_protocol::{
    DocKind, Report, conformance, context_for_file, validate, validate_package,
};
use serde_json::Value;

const USAGE: &str = "\
gateworlds-validate -- Gateworlds world protocol validator

  gateworlds-validate conformance <dir>    run every vector under <dir>
  gateworlds-validate package <dir>...     validate world package directories
  gateworlds-validate doc <kind> <file>    validate one document (world|items|save)
  gateworlds-validate publish <src> <out>  validate packages, then write a static registry
";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let failed = match args.first().map(String::as_str) {
        Some("conformance") if args.len() == 2 => run_conformance(Path::new(&args[1])),
        Some("package") if args.len() >= 2 => run_packages(&args[1..]),
        Some("doc") if args.len() == 3 => run_doc(&args[1], Path::new(&args[2])),
        Some("publish") if args.len() == 3 => run_publish(Path::new(&args[1]), Path::new(&args[2])),
        _ => {
            eprint!("{USAGE}");
            return ExitCode::from(2);
        }
    };
    if failed {
        ExitCode::FAILURE
    } else {
        ExitCode::SUCCESS
    }
}

// ------------------------------------------------------------------ conformance runner

fn run_conformance(dir: &Path) -> bool {
    let outcomes = match conformance::run_dir(dir) {
        Ok(o) => o,
        Err(e) => {
            eprintln!("{e}");
            return true;
        }
    };

    for o in &outcomes {
        println!("  {}  {}", if o.passed() { "ok  " } else { "FAIL" }, o.name);
    }

    // SPEC §11 applies to the runner too: report every failure, not just the first.
    let failed: Vec<&_> = outcomes.iter().filter(|o| !o.passed()).collect();
    if !failed.is_empty() {
        println!();
        for o in &failed {
            println!("─── {}", o.name);
            println!("    {}", o.failure.as_deref().unwrap_or(""));
            if let Some(r) = &o.report {
                if !r.is_ok() {
                    println!("    full report:");
                    print!("{}", render(r));
                }
            }
        }
    }

    println!(
        "\n{} passed, {} failed, {} total",
        outcomes.len() - failed.len(),
        failed.len(),
        outcomes.len()
    );
    !failed.is_empty()
}

// ------------------------------------------------------------------ package / doc modes

fn run_packages(dirs: &[String]) -> bool {
    let mut failed = false;
    for d in dirs {
        let dir = Path::new(d);
        match validate_package(dir) {
            Err(e) => {
                println!("  ERROR {}: {e}", dir.display());
                failed = true;
            }
            Ok(report) if report.is_ok() => println!("  ok    {}", dir.display()),
            Ok(report) => {
                println!("  FAIL  {}", dir.display());
                print!("{}", render(&report));
                failed = true;
            }
        }
    }
    failed
}

fn run_doc(kind: &str, file: &Path) -> bool {
    let Some(kind) = DocKind::parse(kind) else {
        eprintln!("unknown kind {kind:?} (expected world, items or save)");
        return true;
    };
    let Ok(raw) = std::fs::read_to_string(file) else {
        eprintln!("cannot read {}", file.display());
        return true;
    };
    let doc: Value = match serde_json::from_str(&raw) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("{}: bad JSON: {e}", file.display());
            return true;
        }
    };
    let ctx = context_for_file(kind, &doc, file);
    let report = validate(kind, &doc, &ctx);
    if report.is_ok() {
        println!("  ok    {}", file.display());
        false
    } else {
        println!("  FAIL  {}", file.display());
        print!("{}", render(&report));
        true
    }
}

// ------------------------------------------------------------------ output

fn loc(path: &str) -> &str {
    if path.is_empty() { "<root>" } else { path }
}

fn render(report: &Report) -> String {
    let mut s = String::new();
    for f in &report.findings {
        s.push_str(&format!("      {:<28} {}\n", f.code.as_str(), loc(&f.path)));
        s.push_str(&format!("        {}\n", f.detail));
    }
    s
}

// ------------------------------------------------------------------ publish

fn run_publish(src: &Path, out: &Path) -> bool {
    let stamp = std::process::Command::new("date")
        .args(["-u", "+%Y-%m-%dT%H:%M:%SZ"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "1970-01-01T00:00:00Z".into());

    match publish::build(src, out, &stamp) {
        Err(e) => {
            eprintln!("publish failed: {e}");
            true
        }
        Ok(outcome) => {
            for id in &outcome.published {
                println!("  published  {id}");
            }
            for (name, report) in &outcome.rejected {
                println!("  REJECTED   {name}");
                print!("{}", render(report));
            }
            println!(
                "\n{} published, {} rejected -> {}",
                outcome.published.len(),
                outcome.rejected.len(),
                out.display()
            );
            if !outcome.rejected.is_empty() {
                // A registry that quietly drops a package looks identical to one that never
                // had it. Fail loudly so a broken world is noticed at publish time.
                eprintln!("refusing to report success while a package is rejected");
            }
            !outcome.ok()
        }
    }
}
