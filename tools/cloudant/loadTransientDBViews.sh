#!/bin/bash

#
# Copyright 2015-2016 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# drop and recreate the transient whisk cloudant databases.
# NOTE: before editing this file, review the notes in
# whisk.core.entity.WhiskStore as any changes here to the views
# may require changes to the supporting query methods.
#

SCRIPTDIR="$(cd $(dirname "$0")/ && pwd)"
PROPERTIES_FILE="$SCRIPTDIR/../../whisk.properties"

# Looks up a value in a property file.
# arg $1: the path to the property file.
# arg $2: the name of the property to look up
# return (print to stdout): the value of the property.
function getProperty() {
    file=$1
    name=$2
    value=$(cat "$file" | grep "^$name=" |cut -d "=" -f 2)
    echo $value
}

function addRevision() {
    VIEW=$1
    REV=$2

    if [[ $REV =~ ^\"_rev\".* ]]; then
        # updating view
        REV=$REV,
    else
        # loading fresh view
        REV=
    fi

    IFS='%' # change internal field separator to preserve white space
    echo ${VIEW/PREV_REV/$REV}
}

function view() {
    IFS='%' # change internal field separator to preserve white space
    echo '{
      "_id":"_design/whisks", PREV_REV
      "views": {
        "all": {
          "map": "function (doc) {\n  var PATHSEP = \"/\";\n\n  var isPackage = function (doc) {  return (doc.binding !== undefined) };\n  var isAction = function (doc) { return (doc.exec !== undefined) };\n  var isTrigger = function (doc) { return (doc.exec === undefined && doc.binding === undefined && doc.parameters !== undefined) };\n  var isRule = function (doc) {  return (doc.trigger !== undefined) };\n  var isActivation = function (doc) { return (doc.activationId !== undefined) };\n  \n  var collection = function (doc) {\n    if (isPackage(doc)) return \"packages\";\n    if (isAction(doc)) return \"actions\";\n    if (isTrigger(doc)) return \"triggers\";\n    if (isRule(doc)) return \"rules\";\n    if (isActivation(doc)) return \"activations\";\n    return \"??\";\n  };\n\n  try {\n    var ns = doc.namespace.split(PATHSEP);\n    var root = ns[0]; ns.shift();\n    var type = collection(doc);\n    var date = new Date(doc.start || doc.updated);\n    var value = {collection: type, namespace: doc.namespace, name: doc.name, version: doc.version, publish: doc.publish, annotations: doc.annotations};\n    if (isPackage(doc)) {\n      value.binding = Object.keys(doc.binding).length !== 0;\n    } else if (isActivation(doc)) {\n      value.activationId = doc.activationId;\n    }\n    emit([root, date], value);\n  } catch (e) {}\n}"
        },
        "packages": {
          "map": "function (doc) {\n  var PATHSEP = \"/\";\n\n  var isPackage = function (doc) {  return (doc.binding !== undefined) };\n  var isAction = function (doc) { return (doc.exec !== undefined) };\n  var isTrigger = function (doc) { return (doc.exec === undefined && doc.binding === undefined && doc.parameters !== undefined) };\n  var isRule = function (doc) {  return (doc.trigger !== undefined) };\n  var isActivation = function (doc) { return (doc.activationId !== undefined) };\n\n  if (isPackage(doc)) try {\n    var date = new Date(doc.start || doc.updated);\n    emit([doc.namespace, date.getTime(), doc.name], {namespace: doc.namespace, name: doc.name, version: doc.version, publish: doc.publish, annotations: doc.annotations, binding: Object.keys(doc.binding).length !== 0});\n  } catch (e) {}\n}"
        },
        "packages-all": {
          "reduce": "function (keys, values, rereduce) {\n  var isPublicPackage = function(p) { return p.publish && !p.binding; };\n\n  if (rereduce) {\n    return [].concat.apply([], values);\n  } else {\n    return values.filter(isPublicPackage);\n  }\n}",
          "map": "function (doc) {\n  var PATHSEP = \"/\";\n\n  var isPackage = function (doc) {  return (doc.binding !== undefined) };\n  var isAction = function (doc) { return (doc.exec !== undefined) };\n  var isTrigger = function (doc) { return (doc.exec === undefined && doc.binding === undefined && doc.parameters !== undefined) };\n  var isRule = function (doc) {  return (doc.trigger !== undefined) };\n  var isActivation = function (doc) { return (doc.activationId !== undefined) };\n\n  if (isPackage(doc)) try {\n    var date = new Date(doc.start || doc.updated);\n    emit([date.getTime(), doc.name], {namespace: doc.namespace, name: doc.name, version: doc.version, publish: doc.publish, annotations: doc.annotations, binding: Object.keys(doc.binding).length !== 0});\n  } catch (e) {}\n}"
        },
        "actions": {
          "map": "function (doc) {\n  var PATHSEP = \"/\";\n\n  var isPackage = function (doc) {  return (doc.binding !== undefined) };\n  var isAction = function (doc) { return (doc.exec !== undefined) };\n  var isTrigger = function (doc) { return (doc.exec === undefined && doc.binding === undefined && doc.parameters !== undefined) };\n  var isRule = function (doc) {  return (doc.trigger !== undefined) };\n  var isActivation = function (doc) { return (doc.activationId !== undefined) };\n\n  if (isAction(doc)) try {\n    var ns = doc.namespace.split(PATHSEP);\n    var root = ns[0]; ns.shift();\n    var date = new Date(doc.start || doc.updated);\n    emit([doc.namespace, date.getTime(), doc.name], {namespace: doc.namespace, name: doc.name, version: doc.version, publish: doc.publish, annotations: doc.annotations});\n    if (root !== doc.namespace) {\n      emit([root, date.getTime(), doc.name], {namespace: doc.namespace, name: doc.name, version: doc.version, publish: doc.publish, annotations: doc.annotations});\n    }\n  } catch (e) {}\n}"
        },
        "triggers": {
          "map": "function (doc) {\n  var PATHSEP = \"/\";\n\n  var isPackage = function (doc) {  return (doc.binding !== undefined) };\n  var isAction = function (doc) { return (doc.exec !== undefined) };\n  var isTrigger = function (doc) { return (doc.exec === undefined && doc.binding === undefined && doc.parameters !== undefined) };\n  var isRule = function (doc) {  return (doc.trigger !== undefined) };\n  var isActivation = function (doc) { return (doc.activationId !== undefined) };\n\n  if (isTrigger(doc)) try {\n    var ns = doc.namespace.split(PATHSEP);\n    var root = ns[0]; ns.shift();\n    var date = new Date(doc.start || doc.updated);\n    emit([doc.namespace, date.getTime(), doc.name], {namespace: doc.namespace, name: doc.name, version: doc.version, publish: doc.publish, annotations: doc.annotations});\n    if (root !== doc.namespace) {\n      emit([root, date.getTime(), doc.name], {namespace: doc.namespace, name: doc.name, version: doc.version, publish: doc.publish, annotations: doc.annotations});\n    }\n  } catch (e) {}\n}"
        },
        "rules": {
          "map": "function (doc) {\n  var PATHSEP = \"/\";\n\n  var isPackage = function (doc) {  return (doc.binding !== undefined) };\n  var isAction = function (doc) { return (doc.exec !== undefined) };\n  var isTrigger = function (doc) { return (doc.exec === undefined && doc.binding === undefined && doc.parameters !== undefined) };\n  var isRule = function (doc) {  return (doc.trigger !== undefined) };\n  var isActivation = function (doc) { return (doc.activationId !== undefined) };\n\n  if (isRule(doc)) try {\n    var ns = doc.namespace.split(PATHSEP);\n    var root = ns[0]; ns.shift();\n    var date = new Date(doc.start || doc.updated);\n    emit([doc.namespace, date.getTime(), doc.name], {namespace: doc.namespace, name: doc.name, version: doc.version, publish: doc.publish, annotations: doc.annotations});\n    if (root !== doc.namespace) {\n      emit([root, date.getTime(), doc.name], {namespace: doc.namespace, name: doc.name, version: doc.version, publish: doc.publish, annotations: doc.annotations});\n    }\n  } catch (e) {}\n}"
        },
        "activations": {
          "map": "function (doc) {\n  var PATHSEP = \"/\";\n\n  var isPackage = function (doc) {  return (doc.binding !== undefined) };\n  var isAction = function (doc) { return (doc.exec !== undefined) };\n  var isTrigger = function (doc) { return (doc.exec === undefined && doc.binding === undefined && doc.parameters !== undefined) };\n  var isRule = function (doc) {  return (doc.trigger !== undefined) };\n  var isActivation = function (doc) { return (doc.activationId !== undefined) };\n\n  if (isActivation(doc)) try {\n    var date = new Date(doc.start || doc.updated);\n    emit([doc.namespace, date.getTime(), doc.name], {namespace: doc.namespace, name: doc.name, version: doc.version, publish: doc.publish, annotations: doc.annotations, activationId: doc.activationId});\n    emit([doc.namespace+PATHSEP+doc.name, date.getTime()], {namespace: doc.namespace, name: doc.name, version: doc.version, publish: doc.publish, annotations: doc.annotations, activationId: doc.activationId});\n  } catch (e) {}\n}"
        }
      },
      "language": "javascript",
      "indexes": {}
    }'
}

CLOUDANT_USERNAME=$(getProperty "$PROPERTIES_FILE" "cloudant.username")
CLOUDANT_PASSWORD=$(getProperty "$PROPERTIES_FILE" "cloudant.password")
CLOUDANT_DB_PREFIX=$(getProperty "$PROPERTIES_FILE" "cloudant.db.prefix")
source "$SCRIPTDIR/../../config/cloudantSetup.sh"
CURL_ADMIN="curl --user $CLOUDANT_USERNAME:$CLOUDANT_PASSWORD"
URL_BASE="https://$CLOUDANT_USERNAME.cloudant.com"

PREV_REV=`$CURL_ADMIN -X GET $URL_BASE/$CLOUDANT_WHISK_ACTIONS/_design/whisks | awk -F"," '{print $2}'`
$CURL_ADMIN -X POST -H 'Content-Type: application/json' -d "$(addRevision "$(view)" $PREV_REV)" $URL_BASE/$CLOUDANT_WHISK_ACTIONS; echo