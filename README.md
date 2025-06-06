# PSDevOps

This repository contains PowerShell scripts and automation resources used to manage Microsoft Dynamics NAV/Business Central environments.

## Getting Started

1. Clone the repository.
2. Run `Initialize-Environment.ps1` from an elevated PowerShell session to load the modules and set global variables defined in `Configs/Global.cfg`.
3. Use the cmdlets under `Cmdlets/` or the pipelines in `Yml/` to automate environment tasks.

## Repository Structure

- **Cmdlets/** – Custom PowerShell functions grouped into folders (e.g. `EcsRst` for restore operations, `EcsSql` for SQL tasks).
- **Modules/** – Additional modules imported during initialization (`Common`, `NavAdminTools`, `NavModelTools`, `PowershellUtility`).
- **Configs/** – Configuration files such as `Global.cfg` and `SAMPLE_BCServerConfig.json` used by the scripts.
- **Yml/** – Azure DevOps pipeline definitions (e.g. `Import_DataToEnvironment.yml`).
- **docs/** – Markdown documentation explaining pipeline steps.
- **Licenses/** – License files for Business Central deployments.
- **Initialize-Environment.ps1** – Script that installs dependencies and imports all modules and cmdlets.

## Documentation

Additional details about the pipelines can be found in the `docs/` folder. For example, `Import_DataToEnvironment.md` describes the flow of the data restore pipeline.

---

This repository is connected to Codex for automated improvements.
