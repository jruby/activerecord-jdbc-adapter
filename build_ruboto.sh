#!/bin/bash -x

# http://eng.rightscale.com/2015/04/27/dependent-builds-in-travis.html

auth_token=RUBOTO_AUTH_TOKEN
endpoint=https://api.travis-ci.org
repo_id=55572

# Only run for master builds. Pull request builds have the branch set to master,
# so ignore those too.
#
if [ "${TRAVIS_BRANCH}" != "test-trigger-ruboto-build" ]; then
  if [ "${TRAVIS_BRANCH}" != "master" ] || [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
    exit 0
  fi
fi

function travis-api {
  curl -s $endpoint$1 \
       -H "Authorization: token $auth_token" \
       -H 'Content-Type: application/json' \
       "${@:2}"
}

function env-var {
  travis-api /settings/env_vars?repository_id=$repo_id \
             -d "{\"env_var\":{\"name\":\"$1\",\"value\":\"$2\",\"public\":true}}" |
    sed 's/{"env_var":{"id":"\([^"]*\)",.*/\1/'
}

last_master_build_id=`travis-api /repos/$repo_id/branches/master |
                      sed 's/{"branch":{"id":\([0-9]*\),.*/\1/'`

env_var_ids=(`env-var DEPENDENT_BUILD true`
             `env-var TRIGGER_COMMIT $TRAVIS_COMMIT`
             `env-var TRIGGER_REPO $TRAVIS_REPO_SLUG`)

travis-api /builds/$last_master_build_id/restart -X POST

until travis-api /builds/$last_master_build_id | grep '"state":"started"'; do
  sleep 5
done

for env_var_id in "${env_var_ids[@]}"; do
  travis-api /settings/env_vars/$env_var_id?repository_id=$repo_id -X DELETE
done
