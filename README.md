# Minimal Container Images for Databricks Container Service

The dockerfile is based on the official
[databricks/containers](https://github.com/databricks/containers) repository.
Installed ubuntu and python packages are kept to the minimum required
to be used for Databricks Container Service and support the necessary features.

The container images have been tested and verified to work.
They are suitable to be used as base images
to install libraries required for your use cases.

## Availabe Images

For available image tags, please refer to the [compose.yaml](compose.yaml) file.

Or the repository container registry: <https://ghcr.io/yxtay/databricks-container>

## Python Package Versions

The installed python package versions should follow
the latest versions available as of the release dates published on the
[Databricks Runtime releast notes](https://docs.databricks.com/aws/en/release-notes/runtime/).
They should also be compatible with the particular
spark version specified for each runtime version.

## References

- [databricks/containers](https://github.com/databricks/containers)
- [Customize containers with Databricks Container Service](https://docs.databricks.com/aws/en/compute/custom-containers)
- [Databricks Runtime release notes versions and compatibility](https://docs.databricks.com/aws/en/release-notes/runtime/)
