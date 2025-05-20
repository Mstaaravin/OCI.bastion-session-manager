# OCI Bastion Management Tools

![Oracle Cloud Infrastructure](https://www.oracle.com/a/ocom/img/cloud-infrastructure-badge.svg)

## Table of Contents

- [Description](#description)
- [Requirements](#requirements)
- [Installation](#installation)
- [Included Tools](#included-tools)
  - [bastion_manage.sh](#bastion_managesh)
- [Usage](#usage)
  - [Creating Sessions](#creating-sessions)
    - [SSH Sessions](#ssh-sessions)
    - [Port Forwarding Sessions](#port-forwarding-sessions)
  - [Listing Bastions and Sessions](#listing-bastions-and-sessions)
  - [Viewing Details](#viewing-details)
- [SSH Configuration](#ssh-configuration)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Description

This repository contains a set of tools for managing bastion services in Oracle Cloud Infrastructure (OCI). Bastions provide secure and restricted access to resources in private subnets that don't have public endpoints.

The tools allow you to create and manage different types of bastion sessions, list existing bastions, and view details of bastions and sessions.

## Requirements

- Oracle Cloud Infrastructure CLI (OCI CLI) installed and configured ([installation guide](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm))
- OCI CLI configuration file at `~/.oci/config`
- jq (command-line JSON processor) ([download](https://stedolan.github.io/jq/download/))
- Bash (version 4.0 or higher)

## Installation

1. Clone this repository or download the files directly:

```bash
git clone https://github.com/Mstaaravin/oci-bastion-tools.git
cd oci-bastion-tools
```

2. Make the scripts executable:

```bash
chmod +x bastion_manage.sh
```

## Included Tools

### bastion_manage.sh

Comprehensive script for managing OCI bastions and their sessions. It allows you to:

- Create managed SSH sessions
- Create port forwarding sessions
- List bastions in a compartment
- List active sessions for a bastion
- Show detailed information about bastions and sessions
- Automatically generate SSH configurations for easy access to target resources

## Usage

The `bastion_manage.sh` script uses a hierarchical command structure:

```bash
./bastion_manage.sh <verb> <object> [options]
```

Where:

- `<verb>` can be: `create`, `list`, `show`, `help`
- `<object>` can be: `bastion`, `session-ssh`, `session-forwarding`

### Creating Sessions

#### SSH Sessions

Managed SSH sessions allow direct connection to Compute instances:

```bash
./bastion_manage.sh create session-ssh -b <bastion-ocid> -n <session-name> --target-id <target-ocid> [options]
```

Main options:
- `-b, --bastion-id OCID`: Bastion OCID (required)
- `-n, --name NAME`: Session name (required)
- `--target-id OCID`: Target resource OCID (required)
- `--target-user USER`: Target OS username (default: opc)
- `--ttl SECONDS`: Session time-to-live in seconds (default: 3600)
- `--key-type TYPE`: Key type (PUB or PEM, default: PUB)
- `--key-file PATH`: Public key file (default: ~/.ssh/id_rsa.pub)

#### Port Forwarding Sessions

Port Forwarding sessions allow port redirection through SSH:

```bash
./bastion_manage.sh create session-forwarding -b <bastion-ocid> -n <session-name> -t <target-ip> -p <port> [options]
```

Main options:
- `-b, --bastion-id OCID`: Bastion OCID (required)
- `-n, --name NAME`: Session name (required)
- `-t, --target-ip IP`: Target private IP address (required)
- `-p, --port PORT`: Target port (default: 22)
- `--ttl SECONDS`: Session time-to-live in seconds (default: 3600)

### Listing Bastions and Sessions

To list all bastions in a compartment:

```bash
./bastion_manage.sh list bastion -c <compartment-ocid> [--all]
```

To list all sessions for a bastion:

```bash
./bastion_manage.sh list session -b <bastion-ocid>
```

### Viewing Details

To show detailed information about a bastion:

```bash
./bastion_manage.sh show bastion -b <bastion-ocid>
```

To show detailed information about a session:

```bash
./bastion_manage.sh show session -b <bastion-ocid> -s <session-name>
```

or

```bash
./bastion_manage.sh show session -b <bastion-ocid> -i <session-ocid>
```

## SSH Configuration

The script includes functionality to automatically generate SSH configuration files. This makes it easier to connect to target resources without having to remember complex SSH commands.

Options:
- `--ssh-config-dir DIR`: Directory for SSH config files (default: ~/.ssh/config.d)
- `--ssh-identity-file FILE`: SSH identity file (default: ~/.ssh/id_rsa)
- `--ssh-config-enabled`: Enable SSH config generation (default)
- `--ssh-config-disabled`: Disable SSH config generation

## Examples

1. Creating an SSH session to a Compute instance:

```bash
./bastion_manage.sh create session-ssh -b ocid1.bastion.oc1..example -n my-session \
  --target-id ocid1.instance.oc1..example --target-user opc
```

2. Creating a Port Forwarding session to a database:

```bash
./bastion_manage.sh create session-forwarding -b ocid1.bastion.oc1..example -n db-session \
  -t 10.0.0.30 -p 1521 --ttl 7200
```

3. Listing all bastions in a compartment and its children:

```bash
./bastion_manage.sh list bastion -c ocid1.compartment.oc1..example --all
```

4. Showing session details:

```bash
./bastion_manage.sh show session -b ocid1.bastion.oc1.region.xxxx -s "my-session-name"
```

## Troubleshooting

If you encounter any issues with the scripts, check the following:

1. Make sure OCI CLI is correctly installed and configured.
2. Verify you have the necessary permissions in OCI to perform the operations.
3. Check that jq is installed and accessible in your PATH.
4. For connectivity issues, verify that the bastion is in an ACTIVE state.
5. If you have problems with sessions, use the `show session` command to verify their status.

For more detailed diagnostic information, use the `--debug` option with any command.

## Contributing

Contributions are welcome. Please follow these steps:

1. Fork the repository
2. Create a branch for your feature (`git checkout -b feature/new-feature`)
3. Make your changes and commit (`git commit -am 'Add new feature'`)
4. Push to your fork (`git push origin feature/new-feature`)
5. Create a Pull Request

## License

This project is licensed under the terms specified in the LICENSE file.

---

**Note**: This project is not an official Oracle product. Oracle Cloud Infrastructure and other Oracle product names are registered trademarks of Oracle Corporation.
