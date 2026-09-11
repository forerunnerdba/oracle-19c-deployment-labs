# Oracle 19c Installation on OEL 8.10 — Without Grid & ASM

This repository contains the **complete commands and execution output** for installing Oracle Database 19c on **Oracle Linux 8.10** without Grid Infrastructure and ASM.

### Environment

* **OS:** Oracle Linux 8.10
* **Oracle Database:** 19c
* **Initial Version:** 19.3.0
* **Final Version:** 19.32.0
* **Installation:** Silent
* **Database:** Single Instance
* **Storage:** Filesystem / OMF
* **CDB:** CAOBS
* **PDB:** CAPDB

### Installation Steps

The log covers:

1. OS and Oracle user configuration
2. Prerequisite RPM installation
3. Oracle 19c silent software installation
4. OPatch upgrade
5. Oracle 19.32 RU patching
6. Database creation using DBCA
7. CDB/PDB configuration
8. Database startup and validation

👉 LinkedIn Article

The complete explanation of the deployment, configuration, troubleshooting and validation is documented in the LinkedIn article:

End-to-End Oracle Database 19c Deployment on Oracle Linux 8.10 - Oracle Restart, ASM & RU 19.32.0

### Complete Command & Output Log

The following log contains the detailed command sequence and actual execution output captured during the deployment:

👉 **[Oracle19cInstallation_OEL8.10_No_Grid_Silent.log](./Oracle19cInstallation_OEL810_No_Grid_Silent.log)**


> This file is provided as a reference containing the commands and output from the installation. Review and modify environment-specific values before using them on another server.

---

## 🏗️ Environment

| Component           | Version / Configuration     |
| ------------------- | --------------------------- |
| Operating System    | Oracle Linux 8.10           |
| Cloud Platform      | Oracle Cloud Infrastructure |
| Database            | Oracle Database 19c         |
| Database RU         | 19.32.0                     |
| Storage             | File System                 |
| Installation        | Single Instnace             |
| Configuration       | Standalone Server           |
| CDB                 | CAOBS                       |
| PDB                 | CAPDB                       |

⚠️ Disclaimer

This repository documents a tested Oracle Database 19c deployment performed in a specific Oracle Linux 8.10 environment.

The commands, paths, package versions, storage configuration and database parameters may need to be modified for other environments.

Before using these procedures in production, review:

    Oracle certification requirements
    Oracle documentation
    Oracle Linux requirements
    Storage requirements
    Security requirements
    Backup and recovery requirements
    High availability requirements
    Organizational standards

🔐 Security

Sensitive information such as passwords, private keys, tokens, credentials and environment-specific secrets has been removed or replaced with placeholders before publication.

Do not commit production credentials, private keys or other sensitive information to GitHub.

👨‍💻 Author

Chakravarthy P

Oracle Database Administrator / SME

Areas of interest:

    Oracle Database
    Oracle RAC
    Oracle ASM
    Oracle Data Guard
    Oracle Restart
    Oracle Cloud
    Microsoft Azure
    Database Migration
    Oracle Patching
    Ansible Automation
    Linux

⭐ Feedback

If you find this documentation useful, feel free to share your feedback, suggestions or corrections. Please consider giving the repository a Star.

The objective is to continuously improve the documentation and capture practical Oracle DBA deployment experiences.
