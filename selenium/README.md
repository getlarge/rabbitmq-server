# Automated End-to-End testing with Mocha and Selenium

## What is it?

It is a solution that allows you to write end-to-end tests in Javascript. The solution
takes care of:

    - generating the required RabbitMQ configuration  
    - deploying RabbitMQ with the generated configuration in 3 ways:  
        - from source via `make run-broker`.
        - with docker via a single docker instance.
        - with docker compose via a 3-node cluster.
    - deploying any other dependencies required by the test case such as:
        - keycloak
        - uaa
        - ldap
        - http authentication backend
        - http proxy
        - http portal
    - running the test cases
    - capturing the logs from RabbitMQ and all the dependencies
    - stopping RabbitMQ and all the dependencies

## Integration with Github actions

These are the three github workflows that run end-to-end tests:
- [test-management-ui.yaml](.github/workflows/test-management-ui.yaml) Runs all the test suites
listed on the file [short-suite-management-ui](selenium/short-suite-management-ui). It tests the management ui deployed on a 3-node cluster. It is invoked on every push to a branch.
- [test-management-ui-for-prs.yaml](.github/workflows/test-management-ui.yaml) Runs all the test suites
listed on the file [full-suite-management-ui](selenium/full-suite-management-ui). It tests the management ui deployed on a single docker instance. It is invoked on every push to a PR.
- [test-authnz.yaml](.github/workflows/test-authnz.yaml) Runs all the test suites
listed on the file [full-suite-authnz-messaging](selenium/full-suite-authnz-messaging). It is invoked on every push to a PR and/or branch.


## Prerequisites

The following must be installed to run the tests:
- make
- docker
- curl

# Organization of test cases

`test` folder contains the test cases written in Javascript using Mocha framework.
Test cases are grouped into folders based on the area of functionality.
For instance, `test/basic-auth` contains test cases that validates basic authentication. Another example, a bit more complex, is `test/oauth` where the test cases are stored in subfolders. For instance, `test/oauth/with-sp-initiated` which validate OAuth 2 authorization where users come to RabbitMQ without any token and RabbitMQ initiates the authorization process.  

The `test` folder also contains the necessary configuration files. For instance, `test/basic-auth` contains `rabbitmq.conf` file which is also shared by other test cases such as `test/definitions` or `test/limits`.

`suites` folder contains one bash script per test suite. A test suite executes all the test cases under
a folder with certain configuration. More on configuration on the next section.

`bin` folder contains as it is expected utility scripts used to run the test suites.


# How to run the tests

There are two ways to run the tests.

**Headless mode** - This is the mode used by the CI. But you can also run it locally. In this mode, you do
not see any browser interaction, everything happens in the background, i.e. rabbitmq, tests, the browser, and any component the test depends on such as UAA.

**The interactive mode** - This mode is convenient when we are still working on RabbitMQ source code and/or in the selenium tests. In this mode, you run RabbitMQ and tests directly from source to speed things up. The components, such as, UAA or keycloak, run in docker.

**IMPORTANT** - If you intend to switch between version of RabbitMQ, make sure
you run `./clean.sh` to clear any state left from the last test run. 


## Run tests in headless-mode

To run just one suite, you proceed as follows:
```
suites/authnz-mgt/oauth-with-uaa.sh
```

And to a group of suites, like the CI does, you run the command below which runs all
the management ui suites. If you do not pass `full-suite-management-ui`, `run-suites.sh`
defaults to `full-suite-management-ui`.
```
./run-suites.sh full-suite-management-ui
```

Other suites files available are:

- `short-suite-management-ui` which only runs a short set of suites
- `full-suite-authnz` which runs all the suites related to testing auth backends vs protocols

If you want to test your local changes, you can still build an image with these 2 commands from the
root folder of the `rabbitmq-server` repo:
```
cd ../../../../
make package-generic-unix
make docker-image
```
>> Equivalent bazel command: `bazelisk run packaging/docker-image:rabbitmq`

The last command prints something like this:
```
 => => naming to docker.io/pivotalrabbitmq/rabbitmq:3.11.0-rc.2.51.g4f3e539.dirty                                                                            0.0s
```

Or if you prefer to use bazel run instead:
```
bazelisk run packaging/docker-image:rabbitmq
```


To run a suite with a particular docker image you do it like this:
```
cd deps/rabbitmq_management/selenium
RABBITMQ_DOCKER_IMAGE=pivotalrabbitmq/rabbitmq:3.11.0-rc.2.51.g4f3e539.dirty suites/authnz-mgt/oauth-with-uaa-with-mgt-prefix.sh
```
or like this if you built the docker image using bazel:
```
cd deps/rabbitmq_management/selenium
RABBITMQ_DOCKER_IMAGE=bazel/packaging/docker-image:rabbitmq suites/authnz-mgt/oauth-with-uaa-with-mgt-prefix.sh
```

To customise the Selenium docker image, use the env variable `SELENIUM_DOCKER_IMAGE`:

```
cd deps/rabbitmq_management/selenium
SELENIUM_DOCKER_IMAGE=tds-rabbitmq-docker-virtual.usw1.packages.broadcom.com/selenium/standalone-chromium:133.0 ./suites/authnz-mgt/basic-auth.sh
```

To customise the temporary directory for test configuration and intermediate container configuration, use `CONF_DIR_PREFIX`. This
variable defaults to `/tmp`.

```
cd deps/rabbitmq_management/selenium
CONF_DIR_PREFIX="$PWD/temp" ./suites/authnz-mgt/basic-auth.sh
```

## Run tests interactively using your local chrome browser

First you make sure that you have Node.js ready to run the test cases.
```
cd selenium
npm install
```

Before you can run a single test case or all the test cases for a suite, you need to
run RabbitMQ from source and all the components the test cases depends on, if any.

For instance, say you want to run the test cases for the suite `suites/oauth-with-uaa.sh`.

First, open a terminal and launch RabbitMQ in the foreground:
```
suites/authnz-mgt/oauth-with-uaa.sh start-rabbitmq
```

Then, launch all the components, the suite depends on, in the background:
```
suites/authnz-mgt/oauth-with-uaa.sh start-others
```

And finally, run all the test cases for the suite:
```
suites/authnz-mgt/oauth-with-uaa.sh test
```

Or just one test case:
```
suites/authnz-mgt/oauth-with-uaa.sh test happy-login.js
```

**NOTE**: Nowadays, it is not possible to run all test in interactive mode. It is doable but it has not
been implemented yet.


## Test case configuration

RabbitMQ and other components such as UAA, or Keycloak, require configuration files which varies
depending on the test case scenario. These configuration files must be dynamically generated using these two other files:
- one or many configuration files
- and one or many **.env** file which declare environment variables used to template the former configuration file in order to generate a final configuration file

Configuration files may contain reference to environment variables. And configuration files
may should follow this naming convention: `<prefix>[.<profile>]*<suffix>`. For instance:
- `basic-auth/rabbitmq.conf` It is a configuration file whose **prefix** is `rabbitmq`, the **suffix** is `.conf` and it has no profile associated to it. Inside, it has no reference to environment variables hence the final
configuration file is the raw configuration file.
- `oauth/rabbitmq.conf` Same as `basic-auth/rabbitmq.conf` but this file does have reference to environment variables so the final file will have those variable replaced with their final values
- `oauth/rabbitmq.mgt-prefix.conf` It is a configuration file with the profile `mgt-prefix`

The .env files should follow the naming convention: `.env.<profile>[.<profile>]*`. For instance:
- `.env.docker` It is an .env file which is  used when the profile `docker` is activated
- `oauth/.env.docker.uaa` It is a .env file used when using `oauth` as test folder and the profiles `docker` and `uaa` are both activated

To generate a `rabbitmq.conf` file the process is as follows:
1. Merge any applicable .env file from the test case's configuration folder and from the parent folder, i.e. under `/test` folder and generate a `/tmp/rabbitmq/.env` file
2. Merge any applicable rabbitmq.conf file from the test case's configuration and resolve all the environment variable using `/tmp/rabbitmq/.env` file to produce `/tmp/selenium/<test-suite-name>/rabbitmq/rabbitmq.conf`

## Profiles

The most common profiles are:
- `docker` profile used to indicate that RabbitMQ, the tests and selenium+browser run in docker. This profile is automatically activated when running in headless mode
- `local` profile used to indicate that RabbitMQ and the tests and the browser run locally. This profile is
automatically activated when running in interactive mode

The rest of the components the test cases depends on will typically run in docker such as uaa, keycloak, and the rest.

Besides these two profiles, mutually exclusive, you can have as many profiles as needed. It is just a matter of naming the appropriate file (.env, or rabbitmq.conf, etc) with the profile and activating the profile in the test suite script. For instance `suites/authnz-mgt/oauth-with-uaa.sh` activates two profiles by declaring them in `PROFILES` environment variable as shown below:
```
PROFILES="uaa uaa-oauth-provider"
```

## Chrome vs Chrome driver version mismatch

If you find the following error when you first attempt to run one of the selenium tests
```
SessionNotCreatedError: session not created: This version of ChromeDriver only supports Chrome version 108
Current browser version is 110.0.5481.100 with binary path /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
```
It is because your current Chrome version is newer than the `chromedriver` configured in package.json.
```
  ....
  "dependencies": {
    "chromedriver": "^110.0.0",
  ...
```
To fix the problem, bump the version in your package.json to match your local chrome version and run again the
following command:
```
  npm install
```

## Build mocha-test image using a different Dockefile

```bash 
MOCHA_DOCKER_FILE=\location\of\my\Dockerfile ./run-suites.sh
```

