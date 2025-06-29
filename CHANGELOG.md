# CHANGELOG

## 1.15.0 - 2025-06-23

Don't stop watining and mark deployment as failed, when any container is still in a waiting state

## 1.14.0 - 2025-02-05

Ruby 3.4 support. Drop ruby 3.2 support.

## 1.13.0 - 2024-07-23

Make docker compose command configurable and use `docker compose` instead `docker-compose` by default

## 1.12.0 - 2024-07-09

Make it possible to customize max_tries in monitor_deploy_status (#92)

## 1.11.0 - 2024-06-04

Add set_image command.

## 1.10.0 - 2024-02-29

Drop ruby 3.0 support and add 3.3 support.

## 1.9.2 - 2023-12-11

Improves and simplifies how docker layers are cached and used. Adds `build_and_cache_base` command.

## 1.8.0 - 2023-06-02

Add support for HTTPS_PROXY automatically set for each kubectl command

## 1.7.0 - 2023-01-23

Add support for publishing Honeycomb markers on deployment.

## 1.6.0 - 2022-12-07

Allow more complex deployments. By passing extra options to the deployment command, we allow deployments where there are multiple containers per pod or where there is more than just deployments/cronjobs (like deamonsets or something similar).

## 1.5.3 - 2022-09-20

- fix determining deploy hook status (issue introduced in 1.5.2)

## 1.5.2 - 2022-09-20

- excluse job containter from pod set status check

## 1.5.0 - 2022-04-20

- Drop ruby 2.7 support and test against ruby 3.1
