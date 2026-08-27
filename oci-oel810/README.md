# Oracle Database 19c End-to-End Deployment on Oracle Linux 8.10 on Oracle Cloud

This repository contains the supporting execution log for my LinkedIn article documenting an end-to-end Oracle Database 19c deployment on Oracle Linux 8.10 (OEL 8.10).

The environment is configured as a **single-instance Oracle Restart environment using Oracle ASM**.

## 📌 Overview

This project documents a complete Oracle Database 19c deployment starting from an Oracle Linux 8.10 server and ending with a fullyconfigured and validated Oracle Database environment using Oracle Restart and ASM.

The deployment covers:

- Oracle Linux 8.10 preparation
- Required RPMs and OS configuration
- Oracle users and groups
- Filesystem and LVM configuration
- Swap configuration
- Oracle ASM / ASMLib
- ASM disk preparation
- Oracle Grid Infrastructure 19.3.0
- Oracle Restart configuration
- OPatch upgrade
- Grid Infrastructure 19.32.0 Release Update
- ASM configuration and disk group creation
- Oracle Database 19.3.0
- Database 19.32.0 Release Update
- ASM DATA / REDO / FRA disk groups
- Silent DBCA database creation
- Oracle Restart database registration
- OPatch validation
- DBA_REGISTRY_SQLPATCH validation
- Final Oracle Restart, ASM and database validation

🔍 Important OEL 8.10 Finding

During the initial Oracle Grid Infrastructure 19.3.0 configuration, ASM disk group creation encountered an error:

[DBT-30002] Disk group creation failed

ORA-15018: diskgroup cannot be created

The successful tested approach was to change the sequence and patch the Grid Infrastructure home before completing the ASM configuration.

👉 LinkedIn Article

The complete explanation of the deployment, configuration, troubleshooting and validation is documented in the LinkedIn article:

End-to-End Oracle Database 19c Deployment on Oracle Linux 8.10 - Oracle Restart, ASM & RU 19.32.0

Installation Command & Execution Output

The following log contains the detailed command sequence and actual execution output captured during the deployment:

👉 **[Oracle19c_OEL810_Installation_Command_Output.log](./Oracle19c_OracleCloud_OEL810_Installation_Command_Output.log)**

The .log format is intentional. It preserves the original command-line formatting, SQL*Plus output, OPatch output, ASMCA output, DBCA output, warnings, errors and validation results.

The log includes actual execution results such as:

- OEL 8.10 OS preparation
- RPM installation
- User and group configuration
- Filesystem and swap configuration
- ASMLib configuration
- ASM disk preparation
- Grid Infrastructure installation
- Oracle Restart configuration
- OPatch upgrade
- Grid Infrastructure patching
- ASM configuration
- ASM disk group creation
- Oracle Database installation
- Database patching
- DBCA database creation
- Oracle Restart registration
- ASM validation
- Grid resource validation
- Database validation
- SQL patch registry results

🏗️ Environment
| Component           | Version / Configuration |
| ------------------- | ----------------------- |
| Operating System    | Oracle Linux 8.10       |
| Grid Infrastructure | 19.3.0 → 19.32.0        |
| Database            | Oracle Database 19c     |
| Database RU         | 19.32.0                 |
| Storage             | Oracle ASM / ASMLib     |
| High Availability   | Oracle Restart          |
| Database Type       | Single Instance / CDB   |
| Installation        | Silent Mode             |
| Configuration       | Standalone Server       |

⚠️ Disclaimer

This repository documents a tested Oracle Database 19c deployment performed in a specific Oracle Linux 8.10 environment.

The commands, paths, package versions, storage configuration and database parameters may need to be modified for other environments.

Before using these procedures in production, review:

- Oracle certification requirements
- Oracle documentation
- Oracle Linux requirements
- Storage requirements
- Security requirements
- Backup and recovery requirements
- High availability requirements
- Organizational standards

Always validate device names and storage configuration before executing disk partitioning or ASM-related commands.

🔐 Security

Sensitive information such as passwords, private keys, tokens, credentials and environment-specific secrets has been removed or replaced with placeholders before publication.

Do not commit production credentials, private keys or other sensitive information to GitHub.

👨‍💻 Author

Chakravarthy P

Oracle Database Administrator / SME

Areas of interest:

- Oracle Database
- Oracle RAC
- Oracle ASM
- Oracle Data Guard
- Oracle Restart
- Oracle Cloud
- Microsoft Azure
- Database Migration
- Oracle Patching
- Ansible Automation
- Linux

⭐ Feedback

If you find this documentation useful, feel free to share your feedback, suggestions or corrections.

The objective is to continuously improve the documentation and capture practical Oracle DBA deployment experiences.
