# Functions for bash scripts
#
# YSobolev
# 300119

function functions.variables {
  script_name=$(basename "$0"|sed 's/\.sh//g')
}

function functions.logging {
  while IFS= read -r line; do
    echo "$(date +'%F %T') $line"
  done
}

function functions.lockfile {
  functions.variables
  prefix=${TICKET:-$script_name}
  lock="/tmp/${prefix}.lock"
  case $1 in
    create )
      if [[ -e ${lock} ]]; then
        echo "Lock file ${lock} exists. Exit."
        exit
      else
        touch "${lock}"
      fi
    ;;
    delete )
      rm -f ${lock}
      return $?
    ;;
    * )
      echo "${FUNCNAME} You need specify action: create or delete."
    ;;
  esac
}

# $1 - for using in prompt. "Enter PROMPT:". "password" by default.
# Returns password in variable $pass
function functions.password {
  unset pass
  echo -n "Enter ${1:-password}: "
  while IFS= read -p "${prompt}" -r -s -n 1 char; do
    if [[ ${char} == $'\0' ]] ; then
      break
    elif [[ ${char} == $'\177' ]] ; then
      prompt=$'\b \b'
      pass="${pass%?}"
    else
      prompt='*'
      pass+="${char}"
    fi
  done
  echo
}

# $1 - path in hdfs
# Return count of lines
function functions.hdfsfilecountstring {
  echo -e 'var lines = sc.textFile("'$1'")\nlines.count\nsys.exit()' > /tmp/${TICKET:-$script_name}.scala
  filecnt=$(spark-shell --name "${TICKET:-$script_name}" -i ${TICKET:-$script_name}.scala 2>/dev/null|grep res0|awk '{print $4}')
  return ${filecnt}
}
