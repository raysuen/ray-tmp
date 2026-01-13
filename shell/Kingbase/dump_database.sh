#!/bin/bash
#by raysuen
#v 2.5


back_dir=/kingbase/dump/back/`date +%Y%m%d`
rm_dir=/kingbase/dump/back/`date +%Y%m%d -d "-30 day"`
hostinf="127.0.0.1"
specified_dbs=""  # 用户指定的数据库列表（逗号分隔）
specified_schema=""  # 用户指定的schema

set -e

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

选项:
  -d 数据库列表   指定要备份的数据库（逗号分隔，如：-d db1,db2，与-s配合使用）
  -s schema名     指定要备份的schema（需配合-d指定数据库，备份该schema的结构和数据）
  -h              显示此帮助信息并退出

说明:
  1. 未指定任何选项时，默认备份除系统库外的所有数据库（全量备份）
  2. 指定-s时必须同时指定-d，仅备份指定数据库下的指定schema（包含结构和数据）
  3. 自动删除30天前的备份文件，备份目录：/kingbase/dump/back/[日期]
EOF
}

# 解析命令行参数
parse_args() {
    while getopts "d:s:h" opt; do
        case $opt in
            d) specified_dbs="$OPTARG" ;;
            s) specified_schema="$OPTARG" ;;
            h) show_help; exit 0 ;;
            *) echo "错误：无效选项 '$opt'，使用 -h 查看帮助" >&2; exit 1 ;;
        esac
    done

    # 检查-s参数是否单独使用
    if [[ -n "$specified_schema" && -z "$specified_dbs" ]]; then
        echo "错误：使用-s指定schema时，必须通过-d指定数据库（如：-d db1 -s schema1）" >&2
        exit 1
    fi
}

# 1. 检查数据库状态并获取路径信息
check_database_data(){
    main_proc_num=$(ps -ef|grep -E "kingbase:.*checkpointer"|grep -v grep|wc -l)
    case $main_proc_num in
        0)
            echo "the database is not on live, please input kingbase home path:"
            read kingbase_home
            if [[ ! -d "$kingbase_home" ]] || [[ ! -f "$kingbase_home/Server/bin/kingbase" ]]; then
                echo "kingbase home path is error, please check it and try again !"
                echo ""
                exit
            fi
            server_path=$kingbase_home/Server
            bin_path=$server_path/bin       
            kingbase_path=$bin_path/kingbase
            
            echo "can not get data path from main process, please input the data path:"
            read data_dir
            if [[ ! -d "$data_dir" ]] || [[ ! -f "$data_dir/kingbase.conf" ]]; then
                echo "data path is error"
                echo "you can use: \"find / -name kingbase.conf\" to find it"
                echo "please check and try again !"
                exit 10
            fi          
            ;;
        1)
            KESPID=$(ps -ef|grep -E "kingbase:.*checkpointer"|grep -v grep|awk '{print $3}'|head -1)
            kingbase_path=$(ls -l /proc/$KESPID/exe|awk '{print $NF}')
            data_dir=$(ls -l /proc/$KESPID/cwd|awk '{print $NF}')
            bin_path=${kingbase_path%/*}
            server_path=${bin_path%/*}
            kingbase_home=${server_path%/*}
            ;;      
        *)
            echo "There are multiple KingbaseES main processes, please select one: "
            ps -ef|grep -E "kingbase:.*checkpointer"|grep -v grep|awk '{print $3}'|while read line; do echo "KES PID: $line"; ls -l /proc/$line/exe|awk '{print $NF}'|xargs echo "    CMD : " ;ls -l /proc/$line/cwd|awk '{print $NF}'|xargs echo "    DATA: " ;  done
            echo "Enter KingbaseES PID:"
            read KESPID
            kingbase_path=$(ls -l /proc/$KESPID/exe|awk '{print $NF}')
            data_dir=$(ls -l /proc/$KESPID/cwd|awk '{print $NF}')
            bin_path=${kingbase_path%/*}
            server_path=${bin_path%/*}
            kingbase_home=${server_path%/*}
    esac 
    
    if [ ! -f "$kingbase_path" ]; then
        echo "kingbase_path is error"
        echo "please check and try again !"
        exit 10
    fi
}

# 获取数据库端口
GetPort(){
        if [[ `ls /tmp/.*.KINGBASE.* | egrep -v "lock" | wc -l` -eq 1 ]];then
               kingbase_port=$(ls -1 /tmp/.s.KINGBASE.* 2>/dev/null | grep -Eo '[0-9]+$' | head -1)
        fi
        if [[ "${data_dir: -1}" == "/" ]];then
                data_dir=`echo ${data_dir} | sed 's/.$//'`
        fi

        if [ -z ${kingbase_port} ];then
                arr=(`egrep "^include" ${data_dir}/kingbase.conf | sed "s/'//g" | awk 'BEGIN{print "kingbase.conf"}{print $NF}'`)
                for i in $(seq $((${#arr[@]}-1)) -1 0)
                do
                        kingbase_port=$(egrep -i "^port" ${data_dir}/${arr[$i]} | awk '{print $3}')
                        if [ ! -z ${kingbase_port} ];then
                                break
                        fi
                done
        fi

        if [ -z ${kingbase_port} ];then
                echo "No kingbase port found!!"
                exit 66
        fi
}

# 获取数据库列表（支持用户指定）
db_list(){
    if [[ -n "$specified_dbs" ]]; then
        # 分割用户指定的数据库列表
        IFS=',' read -ra db_array <<< "$specified_dbs"
        # 验证指定的数据库是否存在（使用template1作为查询入口）
        all_dbs=$($bin_path/ksql -Usystem -h ${hostinf} -A -p $kingbase_port template1 -c "select datname from sys_catalog.sys_database;" -t | grep -v '^$')  # 只过滤空行，不删最后一行
        for db in "${db_array[@]}"; do
            if ! echo "$all_dbs" | grep -q "^$db$"; then
                echo "数据库 $db 不存在，跳过..."
            else
                DATABASES="$DATABASES $db"
            fi
        done
        # 检查是否有有效数据库
        if [[ -z "$DATABASES" ]]; then
            echo "没有有效的数据库可备份"
            exit 20
        fi
    else
        # 默认备份排除系统库的所有数据库（使用template1作为查询入口）
        DATABASES=$($bin_path/ksql -Usystem -h ${hostinf} -A -p $kingbase_port template1 -c "select datname as test  from sys_catalog.sys_database where datname not in('test','template1','template0','security','kingbase');" -t | grep -v '^$')  # 同样替换sed为过滤空行
    fi
}

# 备份数据库（支持指定schema，包含数据）
dump_db(){
    [ ! -d ${back_dir} ]&& mkdir -p ${back_dir}
    for db in $DATABASES
    do
        echo "开始备份数据库: $db ${specified_schema:+（schema: $specified_schema）}"
        # 基础备份命令
        dump_cmd="$bin_path/sys_dump -Usystem -h ${hostinf} -p $kingbase_port -Fc -d $db"
        # 若指定了schema，添加-n参数（仅备份该schema，包含结构和数据）
        if [[ -n "$specified_schema" ]]; then
            dump_cmd="$dump_cmd -n $specified_schema"
        fi
        # 输出文件名（包含schema信息）
        output_file="${back_dir}/${db}${specified_schema:+.${specified_schema}}.dump"
        dump_cmd="$dump_cmd -f $output_file"
        
        # 执行备份
        set +e
        if $dump_cmd; then
            echo "备份成功: $output_file"
        else
            echo "备份失败: $db ${specified_schema:+（schema: $specified_schema）}" >&2
        fi
        set -e
    done
}

# 删除旧备份
del_backup() {
    if [[ -z "${rm_dir}" ]]; then
        echo "错误：删除目录未指定" >&2
        return 1
    fi

    resolved_dir=$(realpath -e -- "${rm_dir}" 2>/dev/null) || {
        echo "错误：目录不存在或不可访问 '${rm_dir}'" >&2
        return 2
    }

    local protected_dirs=("/" "/bin" "/sbin" "/usr" "/etc" "/home" "/root" "/var")
    for dir in "${protected_dirs[@]}"; do
        if [[ "${resolved_dir}" == "${dir}" || "${resolved_dir}/" == "${dir}/"* ]]; then
            echo "错误：拒绝删除系统保护目录 '${resolved_dir}'" >&2
            return 3
        fi
    done

    if [[ ! -w "${resolved_dir}" ]]; then
        echo "错误：无删除权限 '${resolved_dir}'" >&2
        return 4
    fi

    if ! rm -rf -- "${resolved_dir}"; then
        echo "删除失败: $?" >&2
        return 6
    fi

    echo "目录已删除: ${resolved_dir}"
    return 0
}

run(){
    parse_args "$@"  # 解析命令行参数
    check_database_data
    GetPort
    db_list
    dump_db
    del_backup
}

run "$@"