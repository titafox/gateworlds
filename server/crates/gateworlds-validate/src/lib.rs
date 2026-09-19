//! Registry publishing for the Gateworlds world protocol.
//!
//! Exposed as a library as well as a binary so the ingest gate can be tested. A gate whose
//! behaviour is only reachable through a CLI is a gate nobody tests.

pub mod publish;
