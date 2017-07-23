#!/usr/bin/env bash

_PHPQA_PHP_VERSION=71;

function displayError()
{
    local exitError=$1;
    printf "Error: ${exitError}\n\n";
}

function displayHelp()
{
    local exitError=$1;
    if [ -z "${exitError}" ]; then
        exitCode=0;
    fi

    if [ "${exitCode}" != "0" ]; then
        displayError "${exitError}";
    fi

    printf "docker-phpqa 0.0.1\n\n";
    printf "Usage:\n";
    printf "\tphpqa <path/to/test.phpt|suite> [<version>]\n\n";

    exit ${exitCode};
}

function parseRunArgs()
{
    _RUN_FILE_PATH=$1
    _RUN_VERSION=$2;

    if [ -z "${_RUN_FILE_PATH}" ] || [ ! -f "${_RUN_FILE_PATH}" ]; then
        displayHelp "You need to provide a phpt file to be tested or pass \`suite\` as first parameter to run the full test suite.";
    fi

    if [ -z "${_RUN_VERSION}" ]; then
        _RUN_VERSION=${_PHPQA_PHP_VERSION};
    elif [ "${_RUN_VERSION}" != "72" ] && [ "${_RUN_VERSION}" != "71" ] && [ "${_RUN_VERSION}" != "70" ] && [ "${_RUN_VERSION}" != "56" ]; then
        displayHelp "The versions supported are 55, 56, 70, 71, 72 or all to run in all available versions.";
    fi
}

function parseArgs()
{
    _COMMAND=$1;
    if [ -z "${_COMMAND}" ] || ( [ "${_COMMAND}" != "run" ] && [ "${_COMMAND}" != "generate" ] ); then
        displayHelp "Unrecognized command ${_COMMAND}.";
    fi

    if [ "${_COMMAND}" = "help" ]; then
        displayHelp;
    fi

    shift;
    _COMMAND_ARGS=$@;
}

function executeRunSuite()
{
    docker run --rm -i -t herdphp/phpqa:${_RUN_VERSION} make test;
    exit 0;
}

function fixRunPath()
{
    _RUN_FILENAME=${_RUN_FILE_PATH##*/};
    if [[ ! "${_RUN_FILE_PATH}" = /* ]]; then
        _RUN_FILE_PATH="$(pwd)/${_RUN_FILE_PATH}";
    fi
}

function singleTest()
{
    docker run --rm -i -t \
        -v ${_RUN_FILE_PATH}:/usr/src/phpt/${_RUN_FILENAME} herdphp/phpqa:${_RUN_VERSION} \
        make test TESTS=/usr/src/phpt/${_RUN_FILENAME} \
        | sed -e "s/Build complete./Test build successfully./" -e "s/Don't forget to run 'make test'./=\)/";
}

function executeRun()
{
    parseRunArgs ${_COMMAND_ARGS};

    if [ "${_RUN_VERSION}" = "all" ]; then
        $(git rev-parse --show-toplevel)/bin/phpqa.sh ${_RUN_FILENAME} 72;
        $(git rev-parse --show-toplevel)/bin/phpqa.sh ${_RUN_FILENAME} 71;
        $(git rev-parse --show-toplevel)/bin/phpqa.sh ${_RUN_FILENAME} 70;
        $(git rev-parse --show-toplevel)/bin/phpqa.sh ${_RUN_FILENAME} 56;
        $(git rev-parse --show-toplevel)/bin/phpqa.sh ${_RUN_FILENAME} 55;
        exit 0;
    fi

    if [ "${_RUN_FILE_PATH}" = "suite" ]; then
        executeRunSuite;
    fi

    fixRunPath;
    singleTest;
}

function parseGenerateArgs()
{
    local generateOptions="-f -c -m -b -e -v -s -k -x -h";
    _GENERATE_DIR=$1;
    _GENERATE_VERSION=${_PHPQA_PHP_VERSION};

    if [ -z "${_GENERATE_DIR}" ] || [[ ${generateOptions} =~ (^|[[:space:]])${_GENERATE_DIR}($|[[:space:]]) ]]; then
        _GENERATE_DIR="$(git rev-parse --show-toplevel)/phpt";
        _GENERATE_ARGS=$@;
    fi

    if [ ! -d "${_GENERATE_DIR}" ]; then
        displayHelp "Directory ${_GENERATE_DIR} does not exist.";
    fi

    if [ -z "${_GENERATE_ARGS}" ]; then
        shift;
        _GENERATE_ARGS=$@;
    fi
}

function fixGenerateDir()
{
    if [[ ! "${_GENERATE_DIR}" = /* ]]; then
        _GENERATE_DIR="$(pwd)/${_GENERATE_DIR}";
    fi
}
function executeGenerate()
{
    parseGenerateArgs ${_COMMAND_ARGS};
    fixGenerateDir;
    docker run --rm -i -t -v ${_GENERATE_DIR}:/usr/src/phpt herdphp/phpqa:72 \
        php scripts/dev/generate-phpt.phar ${_GENERATE_ARGS} | sed "s/php generate-phpt.php /.\/phpqa/";
}

function executeCommand()
{
    local command=$1;
    local commandFunction="$(tr a-z A-Z <<< ${command:0:1})${command:1}";

    "execute${commandFunction}" ${_COMMAND_ARGS};
}

function main()
{
    parseArgs $@;
    executeCommand ${_COMMAND};
}

main $@;

