# Import_DataToEnvironment Pipeline

This document outlines the execution flow for the `Import_DataToEnvironment.yml` pipeline located in the `Yml` folder.  The pipeline automates restoring a SQL backup and preparing a Business Central environment.

## Pipeline overview

- **Pipeline name**: `Import_DataTo_$(AgentPoolName)`
- **Target agent pool**: value of `$(AgentPoolName)`
- **Variables**:
  - `pipelineID` – set from `$(Build.BuildNumber)`
  - `sqlBackupPath` – path to the SQL backup file (optional)
  - `sqlBackupUseLatestProd` – switch to use the latest production backup
  - `keepCurrentBCUserAccess` – optionally keep existing BC user permissions

## Stage flow

The pipeline consists of sequential stages. Each stage runs a PowerShell command after calling `Initialize-Environment.ps1` to load functions and modules.

1. **InitializeProcess** – runs `Initialize-EcsRstRestoreDataOnlyProcess` to set up global restore variables.
2. **CopyFiles** – copies required files locally with `Copy-EcsRstFilesToLocals`.
3. **ExportUserAccessBC** – exports current BC user permissions via `Export-EcsRstCurrentUserAccess`.
4. **ExportSqlDatabaseRoles** – exports SQL role assignments with `Export-EcsRstSqlDatabaseRoles`.
5. **StopNavServerInstanceServices** – stops Business Central service tiers by calling `Stop-EcsRstBCInstanceServices`.
6. **StopTargetNavServerInstance** – stops the target NAV/BC service instance using `Stop-EcsRstNavService`.
7. **RestoreSQLBackup** – restores the SQL backup through `Restore-EcsRstSQLBackup`.
8. **StartTargetNavServerInstance** – starts the service instance via `Start-EcsRstNavService`.
9. **StartNavServerInstanceServices** – restarts service tiers with `Start-EcsRstBCInstanceServices`.
10. **ImportStoredBCUserAccess** – re‑applies stored BC user access settings through `Import-EcsRstUserAccessStored`.
11. **ImportStoredSqlDatabaseRoles** – restores SQL role memberships using `Import-EcsRstSqlDatabaseRoles`.
12. **PostRestoreSQLBackupTasks** – executes post‑restore actions via `Start-EcsRstPostRestoreTasks`.
13. **RestartNavServerInstance** – restarts the NAV/BC instance using `Restart-EcsRstNavService`.
14. **BCSchemaSynchronization** – performs schema synchronization with `Sync-EcsRstNavSchema`.
15. **RegisterSuccessfulRestore** – records success and sends notifications by running `Register-EcsRstSuccessfulRestore`.

Each stage is configured with a timeout and runs only after the previous stage completes successfully.
