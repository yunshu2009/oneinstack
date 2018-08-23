#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://blog.linuxeye.cn
#
# Notes: OneinStack for CentOS/RadHat 6+ Debian 7+ and Ubuntu 12+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/lj2007331/oneinstack

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
clear
printf "
#######################################################################
#       OneinStack for CentOS/RadHat 6+ Debian 7+ and Ubuntu 12+      #
#                     Setup the backup parameters                     #
#       For more information please visit https://oneinstack.com      #
#######################################################################
"
# Check if user is root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

oneinstack_dir=$(dirname "`readlink -f $0`")
pushd ${oneinstack_dir} > /dev/null
. ./options.conf
. ./versions.txt
. ./include/color.sh
. ./include/check_os.sh
. ./include/check_dir.sh
. ./include/download.sh
. ./include/python.sh

while :; do echo
  echo 'Please select your backup destination:'
  echo -e "\t${CMSG}1${CEND}. Localhost"
  echo -e "\t${CMSG}2${CEND}. Remote host"
  echo -e "\t${CMSG}3${CEND}. Aliyun OSS"
  echo -e "\t${CMSG}4${CEND}. Qcloud COS"
  echo -e "\t${CMSG}5${CEND}. UPYUN"
  echo -e "\t${CMSG}6${CEND}. QINIU"
  read -p "Please input a number:(Default 1 press Enter) " desc_bk
  #如果未输入选项，则 desc_bk默认为1
  [ -z "${desc_bk}" ] && desc_bk=1
  ary=(1 2 3 4 5 6 12 13 14 15 16 23 24 25 26 34 35 36 45 46 56 123 124 125 126 134 135 136 145 146 156 234 235 236 245 246 256 345 346 456 1234 1235 1236 2345 2346 3456 12345 12346 13456 23456 123456)
  if [[ "${ary[@]}" =~ "${desc_bk}" ]]; then
    break
  else
    echo "${CWARNING}input error! Please only input number 1,2,12,23,234 and so on${CEND}"
  fi
done

#将“backup_destination=任意值”改为“backup_destination=”,并写入文件
sed -i 's@^backup_destination=.*@backup_destination=@' ./options.conf
#如果输入值有“1”，则将“backup_destination=任意值”改为“backup_destination=local”,并写入文件
[ `echo ${desc_bk} | grep -e 1` ] && sed -i 's@^backup_destination=.*@backup_destination=local@' ./options.conf
#如果输入值有“2”，则将backup_destination值加上remote,并写入文件
[ `echo ${desc_bk} | grep -e 2` ] && sed -i 's@^backup_destination=.*@&,remote@' ./options.conf
#如果输入值有“3”，则将backup_destination值加上oss,并写入文件
[ `echo ${desc_bk} | grep -e 3` ] && sed -i 's@^backup_destination=.*@&,oss@' ./options.conf
[ `echo ${desc_bk} | grep -e 4` ] && sed -i 's@^backup_destination=.*@&,cos@' ./options.conf
[ `echo ${desc_bk} | grep -e 5` ] && sed -i 's@^backup_destination=.*@&,upyun@' ./options.conf
[ `echo ${desc_bk} | grep -e 6` ] && sed -i 's@^backup_destination=.*@&,qiniu@' ./options.conf
sed -i 's@^backup_destination=,@backup_destination=@' ./options.conf

while :; do echo
  echo 'Please select your backup content:'
  echo -e "\t${CMSG}1${CEND}. Only Database"
  echo -e "\t${CMSG}2${CEND}. Only Website"
  echo -e "\t${CMSG}3${CEND}. Database and Website"
  read -p "Please input a number:(Default 1 press Enter) " content_bk
  [ -z "${content_bk}" ] && content_bk=1
  if [[ ! ${content_bk} =~ ^[1-3]$ ]]; then
    echo "${CWARNING}input error! Please only input number 1~3${CEND}"
  else
    break
  fi
done

[ "${content_bk}" == '1' ] && sed -i 's@^backup_content=.*@backup_content=db@' ./options.conf
[ "${content_bk}" == '2' ] && sed -i 's@^backup_content=.*@backup_content=web@' ./options.conf
[ "${content_bk}" == '3' ] && sed -i 's@^backup_content=.*@backup_content=db,web@' ./options.conf

if [[ ${desc_bk} =~ ^[1,2]$ ]]; then
  while :; do echo
    echo "Please enter the directory for save the backup file: "
    read -p "(Default directory: ${backup_dir}): " new_backup_dir
    [ -z "${new_backup_dir}" ] && new_backup_dir="${backup_dir}"
    if [ -z "`echo ${new_backup_dir}| grep '^/'`" ]; then
      echo "${CWARNING}input error! ${CEND}"
    else
      break
    fi
  done
  sed -i "s@^backup_dir=.*@backup_dir=${new_backup_dir}@" ./options.conf
fi

while :; do echo
  echo "Please enter a valid backup number of days: "
  read -p "(Default days: 5): " expired_days
  [ -z "${expired_days}" ] && expired_days=5
  [ -n "`echo ${expired_days} | sed -n "/^[0-9]\+$/p"`" ] && break || echo "${CWARNING}input error! Please only enter numbers! ${CEND}"
done
sed -i "s@^expired_days=.*@expired_days=${expired_days}@" ./options.conf

if [ "${content_bk}" != '2' ]; then
  databases=`${db_install_dir}/bin/mysql -uroot -p$dbrootpwd -e "show databases\G" | grep Database | awk '{print $2}' | grep -Evw "(performance_schema|information_schema|mysql|sys)"`
  while :; do echo
    echo "Please enter one or more name for database, separate multiple database names with commas: "
    read -p "(Default database: `echo $databases | tr ' ' ','`) " db_name
    db_name=`echo ${db_name} | tr -d ' '`
    [ -z "${db_name}" ] && db_name="`echo $databases | tr ' ' ','`"
    D_tmp=0
    for D in `echo ${db_name} | tr ',' ' '`
    do
      [ -z "`echo $databases | grep -w $D`" ] && { echo "${CWARNING}$D was not exist! ${CEND}" ; D_tmp=1; }
    done
    [ "$D_tmp" != '1' ] && break
  done
  sed -i "s@^db_name=.*@db_name=${db_name}@" ./options.conf
fi

if [ "${content_bk}" != '1' ]; then
  websites=`ls ${wwwroot_dir}`
  while :; do echo
    echo "Please enter one or more name for website, separate multiple website names with commas: "
    read -p "(Default website: `echo $websites | tr ' ' ','`) " website_name
    website_name=`echo ${website_name} | tr -d ' '`
    [ -z "${website_name}" ] && website_name="`echo $websites | tr ' ' ','`"
    W_tmp=0
    for W in `echo ${website_name} | tr ',' ' '`
    do
      [ ! -e "${wwwroot_dir}/$W" ] && { echo "${CWARNING}${wwwroot_dir}/$W not exist! ${CEND}" ; W_tmp=1; }
    done
    [ "$W_tmp" != '1' ] && break
  done
  sed -i "s@^website_name=.*@website_name=${website_name}@" ./options.conf
fi

echo
echo "You have to backup the content:"
[ "${content_bk}" != '2' ] && echo "Database: ${CMSG}${db_name}${CEND}"
[ "${content_bk}" != '1' ] && echo "Website: ${CMSG}${website_name}${CEND}"

if [ `echo ${desc_bk} | grep -e 2` ]; then
  > tools/iplist.txt
  while :; do echo
    read -p "Please enter the remote host ip: " remote_ip
    [ -z "${remote_ip}" -o "${remote_ip}" == '127.0.0.1' ] && continue
    echo
    read -p "Please enter the remote host port(Default: 22) : " remote_port
    [ -z "${remote_port}" ] && remote_port=22
    echo
    read -p "Please enter the remote host user(Default: root) : " remote_user
    [ -z "${remote_user}" ] && remote_user=root
    echo
    read -p "Please enter the remote host password: " remote_password
    IPcode=$(echo "ibase=16;$(echo "${remote_ip}" | xxd -ps -u)"|bc|tr -d '\\'|tr -d '\n')
    Portcode=$(echo "ibase=16;$(echo "${remote_port}" | xxd -ps -u)"|bc|tr -d '\\'|tr -d '\n')
    PWcode=$(echo "ibase=16;$(echo "$remote_password" | xxd -ps -u)"|bc|tr -d '\\'|tr -d '\n')
    [ -e "~/.ssh/known_hosts" ] && grep ${remote_ip} ~/.ssh/known_hosts | sed -i "/${remote_ip}/d" ~/.ssh/known_hosts
    ./tools/mssh.exp ${IPcode}P ${remote_user} ${PWcode}P ${Portcode}P true 10
    if [ $? -eq 0 ]; then
      [ -z "`grep ${remote_ip} tools/iplist.txt`" ] && echo "${remote_ip} ${remote_port} ${remote_user} $remote_password" >> tools/iplist.txt || echo "${CWARNING}${remote_ip} has been added! ${CEND}"
      while :; do
        read -p "Do you want to add more host ? [y/n]: " morehost_yn
        if [[ ! ${morehost_yn} =~ ^[y,n]$ ]]; then
          echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
        else
          break
        fi
      done
      [ "${morehost_yn}" == 'n' ] && break
    fi
  done
fi

if [ `echo ${desc_bk} | grep -e 3` ]; then
  if [ ! -e "/usr/local/bin/ossutil" ]; then
    if [ "${OS_BIT}" == '64' ]; then
      wget -qc http://docs-aliyun.cn-hangzhou.oss.aliyun-inc.com/assets/attach/50452/cn_zh/1524643963683/ossutil64 -O /usr/local/bin/ossutil
    elif [ "${OS_BIT}" == '32' ]; then
      wget -qc http://docs-aliyun.cn-hangzhou.oss.aliyun-inc.com/assets/attach/50452/cn_zh/1524643908776/ossutil32 -O /usr/local/bin/ossutil
    fi
    chmod +x /usr/local/bin/ossutil
  fi
  while :; do echo
    echo 'Please select your backup aliyun datacenter:'
    echo -e "\t ${CMSG}1${CEND}. cn-hangzhou-华东 1 (杭州)         ${CMSG}2${CEND}. cn-shanghai-华东 2 (上海)"
    echo -e "\t ${CMSG}3${CEND}. cn-qingdao-华北 1 (青岛)          ${CMSG}4${CEND}. cn-beijing-华北 2 (北京)"
    echo -e "\t ${CMSG}5${CEND}. cn-zhangjiakou-华北 3 (张家口)    ${CMSG}6${CEND}. cn-huhehaote-华北 5(呼和浩特)"
    echo -e "\t ${CMSG}7${CEND}. cn-shenzhen-华南 1 (深圳)         ${CMSG}8${CEND}. cn-hongkong-香港"
    echo -e "\t ${CMSG}9${CEND}. us-west-美西 1 (硅谷)            ${CMSG}10${CEND}. us-east-美东 1 (弗吉尼亚)"
    echo -e "\t${CMSG}11${CEND}. ap-southeast-亚太东南 1 (新加坡) ${CMSG}12${CEND}. ap-southeast-亚太东南 2 (悉尼)"
    echo -e "\t${CMSG}13${CEND}. ap-southeast-亚太东南 3 (吉隆坡) ${CMSG}14${CEND}. ap-southeast-亚太东南 5 (雅加达)"
    echo -e "\t${CMSG}15${CEND}. ap-northeast-亚太东北 1 (日本)   ${CMSG}16${CEND}. ap-south-亚太南部 1 (孟买)"
    echo -e "\t${CMSG}17${CEND}. eu-central-欧洲中部 1 (法兰克福) ${CMSG}18${CEND}. me-east-中东东部 1 (迪拜)"
    read -p "Please input a number:(Default 1 press Enter) " Location
    [ -z "${Location}" ] && Location=1
    if [[ "${Location}" =~ ^[1-9]$|^1[0-8]$ ]]; then
      break
    else
      echo "${CWARNING}input error! Please only input number 1~18${CEND}"
    fi
  done
  [ "${Location}" == '1' ] && Host=oss-cn-hangzhou-internal.aliyuncs.com
  [ "${Location}" == '2' ] && Host=oss-cn-shanghai-internal.aliyuncs.com
  [ "${Location}" == '3' ] && Host=oss-cn-qingdao-internal.aliyuncs.com
  [ "${Location}" == '4' ] && Host=oss-cn-beijing-internal.aliyuncs.com
  [ "${Location}" == '5' ] && Host=oss-cn-zhangjiakou-internal.aliyuncs.com
  [ "${Location}" == '6' ] && Host=oss-cn-huhehaote-internal.aliyuncs.com
  [ "${Location}" == '7' ] && Host=oss-cn-shenzhen-internal.aliyuncs.com
  [ "${Location}" == '8' ] && Host=oss-cn-hongkong-internal.aliyuncs.com
  [ "${Location}" == '9' ] && Host=oss-us-west-1-internal.aliyuncs.com
  [ "${Location}" == '10' ] && Host=oss-us-east-1-internal.aliyuncs.com
  [ "${Location}" == '11' ] && Host=oss-ap-southeast-1-internal.aliyuncs.com
  [ "${Location}" == '12' ] && Host=oss-ap-southeast-2-internal.aliyuncs.com
  [ "${Location}" == '13' ] && Host=oss-ap-southeast-3-internal.aliyuncs.com
  [ "${Location}" == '14' ] && Host=oss-ap-southeast-5-internal.aliyuncs.com
  [ "${Location}" == '15' ] && Host=oss-ap-northeast-1-internal.aliyuncs.com
  [ "${Location}" == '16' ] && Host=oss-ap-south-1-internal.aliyuncs.com
  [ "${Location}" == '17' ] && Host=oss-eu-central-1-internal.aliyuncs.com
  [ "${Location}" == '18' ] && Host=oss-me-east-1-internal.aliyuncs.com
  [ "$(./include/check_port.py ${Host} 80)" == "False" ] && Host=`echo ${Host} | sed 's@-internal@@g'`
  [ -e "/root/.ossutilconfig" ] && rm -f /root/.ossutilconfig
  while :; do echo
    read -p "Please enter the aliyun oss Access Key ID: " KeyID
    [ -z "${KeyID}" ] && continue
    echo
    read -p "Please enter the aliyun oss Access Key Secret: " KeySecret
    [ -z "${KeySecret}" ] && continue
    /usr/local/bin/ossutil ls -e ${Host} -i ${KeyID} -k ${KeySecret} >/dev/null 2>&1
    if [ $? -eq 0 ];then
      /usr/local/bin/ossutil config -e ${Host} -i ${KeyID} -k ${KeySecret} >/dev/null 2>&1
      while :; do echo
        read -p "Please enter the aliyun oss bucket: " Bucket
        /usr/local/bin/ossutil mb oss://${Bucket} >/dev/null 2>&1
        [ $? -eq 0 ] && { echo "${CMSG}[${Bucket}] createbucket OK${CEND}"; sed -i "s@^oss_bucket=.*@oss_bucket=${Bucket}@" ./options.conf; break; } || echo "${CWARNING}[${Bucket}] already exists, You need to use the OSS Console to create a bucket for storing.${CEND}"
      done
      break
    fi
  done
fi

if [ `echo ${desc_bk} | grep -e 4` ]; then
  [ ! -e "${python_install_dir}/bin/python" ] && Install_Python
  [ ! -e "${python_install_dir}/lib/coscmd" ] && ${python_install_dir}/bin/pip install coscmd >/dev/null 2>&1
  while :; do echo
    echo 'Please select your backup qcloud datacenter:'
    echo -e "\t ${CMSG} 1${CEND}. 北京一区(华北)  ${CMSG}2${CEND}. 北京"
    echo -e "\t ${CMSG} 3${CEND}. 上海(华东)      ${CMSG}4${CEND}. 广州(华南)"
    echo -e "\t ${CMSG} 5${CEND}. 成都(西南)      ${CMSG}6${CEND}. 重庆"
    echo -e "\t ${CMSG} 7${CEND}. 新加坡          ${CMSG}8${CEND}. 香港"
    echo -e "\t ${CMSG} 9${CEND}. 多伦多         ${CMSG}10${CEND}. 法兰克福"
    echo -e "\t ${CMSG}11${CEND}. 孟买           ${CMSG}12${CEND}. 首尔"
    echo -e "\t ${CMSG}13${CEND}. 硅谷           ${CMSG}14${CEND}. 弗吉尼亚"
    echo -e "\t ${CMSG}15${CEND}. 曼谷           ${CMSG}16${CEND}. 莫斯科"
    read -p "Please input a number:(Default 1 press Enter) " Location
    [ -z "${Location}" ] && Location=1
    if [[ "${Location}" =~ ^[1-9]$|^1[0-6]$ ]]; then
      break
    else
      echo "${CWARNING}input error! Please only input number 1~16${CEND}"
    fi
  done
  [ "${Location}" == '1' ] && region='ap-beijing-1'
  [ "${Location}" == '2' ] && region='ap-beijing'
  [ "${Location}" == '3' ] && region='ap-shanghai'
  [ "${Location}" == '4' ] && region='ap-guangzhou'
  [ "${Location}" == '5' ] && region='ap-chengdu'
  [ "${Location}" == '6' ] && region='ap-chongqing'
  [ "${Location}" == '7' ] && region='ap-singapore'
  [ "${Location}" == '8' ] && region='ap-hongkong'
  [ "${Location}" == '9' ] && region='na-toronto'
  [ "${Location}" == '10' ] && region='eu-frankfurt'
  [ "${Location}" == '11' ] && region='ap-mumbai'
  [ "${Location}" == '12' ] && region='ap-seoul'
  [ "${Location}" == '13' ] && region='na-siliconvalley'
  [ "${Location}" == '14' ] && region='na-ashburn'
  [ "${Location}" == '15' ] && region='ap-bangkok'
  [ "${Location}" == '16' ] && region='eu-moscow'
  while :; do echo
    read -p "Please enter the Qcloud COS APPID: " APPID
    [ -z "${APPID}" ] && continue
    echo
    read -p "Please enter the Qcloud COS SecretId: " SecretId
    [ -z "${SecretId}" ] && continue
    echo
    read -p "Please enter the Qcloud COS SecretKey: " SecretKey
    [ -z "$SecretKey" ] && continue
    echo
    read -p "Please enter the Qcloud COS bucket: " bucket
    [ -z "${bucket}" ] && continue
    echo
    ${python_install_dir}/bin/coscmd config -u ${APPID} -a ${SecretId} -s $SecretKey -r $region -b ${bucket} >/dev/null 2>&1
    ${python_install_dir}/bin/coscmd list >/dev/null 2>&1
    if [ $? = 0 ]; then
      echo "${CMSG}APPID/SecretId/SecretKey/region/bucket OK${CEND}"
      echo
      break
    else
      echo "${CWARNING}input error! APPID/SecretId/SecretKey/region/bucket invalid${CEND}"
    fi
  done
fi

if [ `echo ${desc_bk} | grep -e 5` ]; then
  if [ ! -e "/usr/local/bin/upx" ]; then
    if [ "${OS_BIT}" == '64' ]; then
      wget -qc http://collection.b0.upaiyun.com/softwares/upx/upx-linux-amd64-v0.2.3 -O /usr/local/bin/upx
    elif [ "${OS_BIT}" == '32' ]; then
      wget -qc http://collection.b0.upaiyun.com/softwares/upx/upx-linux-386-v0.2.3 -O /usr/local/bin/upx
    fi
    chmod +x /usr/local/bin/upx
  fi
  while :; do echo
    read -p "Please enter the upyun ServiceName: " ServiceName
    [ -z "${ServiceName}" ] && continue
    echo
    read -p "Please enter the upyun Operator: " Operator
    [ -z "${Operator}" ] && continue
    echo
    read -p "Please enter the upyun Password: " Password
    [ -z "${Password}" ] && continue
    echo
    /usr/local/bin/upx login ${ServiceName} ${Operator} ${Password} >/dev/null 2>&1
    if [ $? = 0 ]; then
      echo "${CMSG}ServiceName/Operator/Password OK${CEND}"
      echo
      break
    else
      echo "${CWARNING}input error! ServiceName/Operator/Password invalid${CEND}"
    fi
  done
fi

if [ `echo ${desc_bk} | grep -e 6` ]; then
  if [ ! -e "/usr/local/bin/qrsctl" ]; then
    if [ "${OS_BIT}" == '64' ]; then
      wget -qc http://devtools.qiniu.com/linux/amd64/qrsctl -O /usr/local/bin/qrsctl
    elif [ "${OS_BIT}" == '32' ]; then
      wget -qc http://devtools.qiniu.com/linux/386/qrsctl -O /usr/local/bin/qrsctl
    fi
    chmod +x /usr/local/bin/qrsctl
  fi
  if [ ! -e "/usr/local/bin/qshell" ]; then
    wget -qc http://devtools.qiniu.com/qshell-v2.1.8.zip -O /tmp/qshell-v2.1.8.zip
    unzip -q /tmp/qshell-v2.1.8.zip -d /tmp/
    if [ "${OS_BIT}" == '64' ]; then
      /bin/cp /tmp/qshell-linux-x64 /usr/local/bin/qshell
    elif [ "${OS_BIT}" == '32' ]; then
      /bin/cp /tmp/qshell-linux-x86 /usr/local/bin/qshell
    fi
    chmod +x /usr/local/bin/qshell
    rm -f /tmp/qshell*
  fi
  while :; do echo
    echo 'Please select your backup qiniu datacenter:'
    echo -e "\t ${CMSG} 1${CEND}. 华东            ${CMSG}2${CEND}. 华北"
    echo -e "\t ${CMSG} 3${CEND}. 华南            ${CMSG}4${CEND}. 北美"
    echo -e "\t ${CMSG} 5${CEND}. 东南亚" 
    read -p "Please input a number:(Default 1 press Enter) " Location
    [ -z "${Location}" ] && Location=1
    if [[ "${Location}" =~ ^[1-5]$ ]]; then
      break
    else
      echo "${CWARNING}input error! Please only input number 1~5${CEND}"
    fi
  done
  [ "${Location}" == '1' ] && zone='z0'
  [ "${Location}" == '2' ] && zone='z1'
  [ "${Location}" == '3' ] && zone='z2'
  [ "${Location}" == '4' ] && zone='na0'
  [ "${Location}" == '5' ] && zone='as0'
  while :; do echo
    read -p "Please enter the qiniu AccessKey: " AccessKey 
    [ -z "${AccessKey}" ] && continue
    echo
    read -p "Please enter the qiniu SecretKey: " SecretKey 
    [ -z "${SecretKey}" ] && continue
    echo
    read -p "Please enter the qiniu bucket: " bucket
    [ -z "${bucket}" ] && continue
    echo
    /usr/local/bin/qshell account ${AccessKey} ${SecretKey}
    /usr/local/bin/qrsctl login ${AccessKey} ${SecretKey}
    if /usr/local/bin/qrsctl bucketinfo ${bucket} > /dev/null 2>&1; then
      sed -i "s@^qiniu_bucket=.*@qiniu_bucket=${bucket}@" ./options.conf
      echo "${CMSG}AccessKey/SecretKey OK${CEND}"
      echo
      break
    elif /usr/local/bin/qrsctl mkbucket ${bucket} ${zone} > /dev/null 2>&1; then
      /usr/local/bin/qrsctl private ${bucket} 1
      echo "${CMSG}[${bucket}] createbucket OK${CEND}"
      sed -i "s@^qiniu_bucket=.*@qiniu_bucket=${bucket}@" ./options.conf
      echo "${CMSG}AccessKey/SecretKey OK${CEND}"
      echo
      break
    else 
      echo "${CWARNING}input error! AccessKey/SecretKey invalid${CEND}"
    fi
  done
fi
