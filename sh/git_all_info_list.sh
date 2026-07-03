#!/bin/bash
set -uo pipefail

list_color_init() {
    export gl_hui=$'\033[38;5;59m'
    export gl_hong=$'\033[38;5;9m'
    export gl_lv=$'\033[38;5;10m'
    export gl_huang=$'\033[38;5;11m'
    export gl_lan=$'\033[38;5;32m'
    export gl_bai=$'\033[38;5;15m'
    export gl_zi=$'\033[38;5;13m'
    export gl_bufan=$'\033[38;5;14m'
    export reset=$'\033[0m'
}
list_color_init

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

print_title() {
    local title="$1"
    echo -e "\n${gl_huang}>>>【${title}】${gl_bufan}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

print_kv() {
    local k="$1"
    local v="$2"
    printf "%s%s\t%s%s\n" "${gl_lan}" "${k}" "${gl_bufan}" "${v}" | column_if_available
}

print_single_tag() {
    local tag="$1"
    echo -e ""
    echo -e "${gl_huang}>>>【版本标签】${gl_lv}${tag}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local full_raw
    full_raw=$(git show "${tag}" 2>/dev/null | sed '/^diff --git/Q')
    if [[ -z "${full_raw}" ]]; then
        printf "%s%s\t%s%s\n" "$gl_huang" "提示" "$gl_hong" "标签 ${tag} 读取失败" "$reset" | column_if_available
        return 0
    fi

    echo "${full_raw}" | sed '/^tag '"${tag}"'/d' | awk -v key_color="$gl_lan" -v val_color="$gl_bufan" -v reset="$reset" '
    BEGIN {
        FS=": "; OFS="\t"
        map_key["Tagger"] = "标签创建人"
        map_key["Date"] = "标签创建时间"
        map_key["commit"] = "绑定提交哈希"
        map_key["Author"] = "提交作者"

        map_week["Mon"]="周一"; map_week["Tue"]="周二"; map_week["Wed"]="周三"
        map_week["Thu"]="周四"; map_week["Fri"]="周五"; map_week["Sat"]="周六"; map_week["Sun"]="周日"

        map_month["Jan"]="01月"; map_month["Feb"]="02月"; map_month["Mar"]="03月"; map_month["Apr"]="04月"
        map_month["May"]="05月"; map_month["Jun"]="06月"; map_month["Jul"]="07月"; map_month["Aug"]="08月"
        map_month["Sep"]="09月"; map_month["Oct"]="10月"; map_month["Nov"]="11月"; map_month["Dec"]="12月"

        state = "tag_info"
        desc_flag = 0
        msg_flag = 0
    }

    /^commit [0-9a-f]+/ {
        sub(/^commit /,"",$0)
        print key_color "绑定提交哈希" reset, val_color $0 reset
        state = "commit_info"
        next
    }

    state=="tag_info" && /^Tagger/ {
        print key_color map_key["Tagger"] reset, val_color $2 reset
        desc_flag=0
        next
    }

    state=="tag_info" && /^Date/ {
        raw_dt = $2
        split(raw_dt, dt, " ")
        w=dt[1]; m=dt[2]; day=dt[3]; time=dt[4]; year=dt[5]; zone=dt[6]
        cn_week = w in map_week ? map_week[w] : w
        cn_month = m in map_month ? map_month[m] : m
        cn_dt = year "年" cn_month day "日 " time " " cn_week " " zone
        print key_color map_key["Date"] reset, val_color cn_dt reset
        desc_flag=0
        next
    }

    state=="tag_info" && NF>0 && !/^[A-Za-z]+: / {
        gsub(/^[ \t]+/,"",$0)
        if (desc_flag == 0) {
            print key_color "标签备注" reset, val_color $0 reset
            desc_flag=1
        } else {
            print key_color "" reset, val_color $0 reset
        }
        next
    }

    state=="commit_info" && /^Author/ {
        print key_color map_key["Author"] reset, val_color $2 reset
        msg_flag=0
        next
    }

    state=="commit_info" && /^Date/ { next }

    state=="commit_info" && NF>0 {
        gsub(/^[ \t]+/,"",$0)
        gsub(/update/,"更新",$0)
        if (msg_flag == 0) {
            print key_color "提交说明" reset, val_color $0 reset
            msg_flag=1
        } else {
            print key_color "" reset, val_color $0 reset
        }
        next
    }
    ' | column_if_available
}

git_show_all_info() {
    local target_dir="$PWD"
    local arg

    for arg in "$@"; do
        target_dir=$(realpath "$arg")
    done

    local origin_pwd="$PWD"
    if ! cd "${target_dir}"; then
        echo -e "${gl_hong}错误：目录 ${target_dir} 不存在或无法进入！${gl_bai}"
        break_end
        return 1
    fi

    clear
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo -e "${gl_hong}错误：「${target_dir}」不是合法Git工作仓库！${gl_bai}"
        cd "${origin_pwd}"
        break_end
        return 0
    fi

    local repo_name
    repo_name=$(basename "$PWD")
    echo -e "${gl_zi}>>> 项目仓库：${gl_huang}${repo_name}${gl_zi} 完整信息汇总${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    print_title "仓库根目录"
    print_kv "本地路径" "$(git rev-parse --show-toplevel)"
    print_kv "完整提交哈希" "$(git rev-parse HEAD)"
    print_kv "简短提交哈希" "$(git rev-parse --short HEAD)"

    print_title "Git用户配置信息"
    print_kv "本地仓库用户名" "$(git config --local user.name 2>/dev/null || echo 未设置)"
    print_kv "本地仓库邮箱" "$(git config --local user.email 2>/dev/null || echo 未设置)"
    print_kv "全局用户名" "$(git config --global user.name 2>/dev/null || echo 未设置)"
    print_kv "全局邮箱" "$(git config --global user.email 2>/dev/null || echo 未设置)"

    print_title "远程仓库配置"
    git remote -v | awk -v kc="$gl_lan" -v vc="$gl_bufan" -v r="$reset" '{
        if(NF==3){
            print kc"远程名称"r, vc$1r;
            print kc"仓库地址"r, vc$2r;
            print kc"同步类型"r, vc$3r;
            print ""
        }
    }' | column_if_available

    print_title "当前分支上游关联"
    git branch -vv | awk -v kc="$gl_lan" -v vc="$gl_bufan" -v r="$reset" '
    /^\*/{
        sub(/^\* /,"")
        split($0,arr," ")
        print kc"本地分支"r,vc arr[1]r
        print kc"关联远程分支"r,vc arr[3]r
    }' | column_if_available

    print_title "本地与远程提交差异"
    local ahead_cnt
    ahead_cnt=$(git rev-list --count HEAD ^origin/main 2>/dev/null)
    local behind_cnt
    behind_cnt=$(git rev-list --count ^HEAD origin/main 2>/dev/null)
    print_kv "本地领先远程提交数" "${ahead_cnt:-0}"
    print_kv "本地落后远程提交数" "${behind_cnt:-0}"

    print_title "仓库本地配置"
    git config --local --list | awk -v kc="$gl_lan" -v vc="$gl_bufan" -v r="$reset" '
    BEGIN{FS="=";OFS="\t"}
    {
        sub(/=/,"\t");
        print kc$1r, vc$2r
    }' | column_if_available

    print_title "全部分支列表(本地+远程)"
    git branch -a | awk -v cur="$gl_lv" -v rem="$gl_huang" -v nor="$gl_bai" '
    /^\*/ {print cur "【当前分支】" substr($0,2);next}
    /remotes\// {print rem "【远程】" substr($0,9);next}
    {print nor "【本地】" $0}
    '

    print_title "仓库所有版本标签"
    local tag_list
    tag_list=$(git tag 2>/dev/null | sort -t'v' -k2 -nr)
    if [[ -z "${tag_list}" ]]; then
        echo -e "${gl_hong}当前仓库无任何版本标签${gl_bai}"
    else
        echo "${tag_list}"
        echo -e "${gl_hui}———— 标签详细信息 ————${gl_bai}"
        while IFS= read -r single_tag; do
            [[ -z "${single_tag}" ]] && continue
            print_single_tag "${single_tag}"
        done <<< "${tag_list}"
    fi

    print_title "当前分支最新提交"
    git log --oneline -1 | awk -v c="$gl_lv" '{print c $0}'
    echo ""
    git show HEAD --pretty=full -q | awk -v kc="$gl_lan" -v vc="$gl_bufan" -v r="$reset" '
    BEGIN{FS=": ";OFS="\t"}
    /^commit/ {sub(/commit /,"");print kc"提交哈希"r,vc$0r;next}
    /^Author/ {print kc"提交作者"r,vc$2r;next}
    /^Date/ {print kc"提交时间"r,vc$2r;next}
    NF>0 && !/^[A-Za-z]+:/ {
        gsub(/^[ \t]+/,"");gsub(/update/,"更新");
        print kc"提交备注"r,vc$0r
    }' | column_if_available

    print_title "仓库整体提交统计"
    print_kv "仓库总提交次数" "$(git rev-list --all | wc -l)"
    print_kv "仓库跟踪文件总数" "$(git ls-files | wc -l)"

    print_title "全仓库提交作者统计"
    local stat_log
    stat_log=$(git shortlog -sn 2>/dev/null)
    if [[ -z "${stat_log}" ]]; then
        git log --format="%an <%ae>" | sort | uniq -c | sort -nr | awk -v kc="$gl_lan" -v vc="$gl_bufan" '{
            print kc"提交次数"r,vc$1r;
            print kc"作者信息"r,vc substr($0,index($0,$2))r;
            print ""
        }' | column_if_available
    else
        echo "${stat_log}" | awk -v kc="$gl_lan" -v vc="$gl_bufan" '{
            print kc"提交次数"r,vc$1r;
            print kc"作者名称"r,vc substr($0,index($0,$2))r;
            print ""
        }' | column_if_available
    fi

    print_title "工作区变更状态"
    git status -s | awk -v add="$gl_lv" -v mod="$gl_huang" -v del="$gl_hong" '
    /^A/ {print add "【新增】" substr($0,4);next}
    /^M/ {print mod "【修改】" substr($0,4);next}
    /^D/ {print del "【删除】" substr($0,4);next}
    {print $0}
    '
    if [[ -z "$(git status -s)" ]]; then
        echo -e "${gl_lv}工作区无未提交修改${gl_bai}"
    fi

    print_title "忽略规则(.gitignore)"
    if [[ -f .gitignore ]]; then
        cat .gitignore | awk -v gray="$gl_hui" '{print gray $0}'
    else
        echo -e "${gl_hong}仓库不存在.gitignore文件${gl_bai}"
    fi

    print_title "仓库底层对象存储统计"
    git count-objects -v | awk -v kc="$gl_lan" -v vc="$gl_bufan" '
    BEGIN{FS=": ";OFS="\t"}
    {print kc$1r,vc$2r}
    ' | column_if_available

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    cd "${origin_pwd}"
    break_end
}

git_show_all_info "$@"
