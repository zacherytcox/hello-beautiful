# hello-beautiful

This project is to build a simple application and technologies surrounding developing, testing, and deploying an application.

## Future Enhancements (WIP)

Build
- [ ] Instructions for Windows users to use [WSL](https://docs.microsoft.com/en-us/windows/wsl/about)

Template
- [ ] Reduce IAM Role Policy permissions.
- [ ] Clean up template object names.

Pre-Commit Hooks
- [ ] https://github.com/awslabs/git-secrets
- [ ] https://github.com/koalaman/shellcheck
- [ ] https://github.com/pre-commit/pre-commit-hooks#trailing-whitespace

Pipeline
- [ ] Pipeline Linters/Checks
- [ ] SAST for Code



## Installation

<!-- Use the package manager [pip](https://pip.pypa.io/en/stable/) to install foobar. -->

<!-- 
```bash
pip install foobar
``` -->

## Usage

```bash
#Configure local aws credentials
aws configure

#Deploy Pipeline
$ sh build.sh
```

Please access the AWS Console and Update the CodeStar Connection [here](https://console.aws.amazon.com/codesuite/settings/connections?region=us-east-1).

Afterwards, within the deployed pipeline, press "Release Change" [here](https://console.aws.amazon.com/codesuite/codepipeline/pipelines?region=us-east-1).


```bash
#Delete Pipeline and resources created by pipeline
$ sh build.sh delete
```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.