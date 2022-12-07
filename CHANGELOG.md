# CHANGELOG

## 1.6.0 - 2022-12-07

Allow more complex deployments. By passing extra options to the deployment command, we allow deployments where there are multiple containers per pod or where there is more than just deployments/cronjobs (like deamonsets or something similar).

## 1.5.3 - 2022-09-20

- fix determining deploy hook status (issue introduced in 1.5.2)

## 1.5.2 - 2022-09-20

- excluse job containter from pod set status check

## 1.5.0 - 2022-04-20

- Drop ruby 2.7 support and test against ruby 3.1
