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

print_single_tag() {
    local tag="$1"
    echo -e ""
    echo -e "${gl_huang}>>>【Git标签】${gl_lv}${tag}${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    local full_raw
    full_raw=$(git show "${tag}" 2>/dev/null | sed '/^diff --git/Q')
    if [[ -z "${full_raw}" ]]; then
        printf "%s%s\t%s%s\n" "$gl_huang" "提示" "$gl_huang" "标签 ${tag} 读取失败" "$reset" | column_if_available
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

list_all_full_tags() {
    clear
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo -e "${gl_hong}当前目录不是Git仓库！${gl_bai}"
        break_end
        return 0
    fi

    local tag_list
    tag_list=$(git tag 2>/dev/null | sort -t'v' -k2 -nr | head -n3)
    local current_dir_name
    current_dir_name=$(basename "$PWD") 

    if [[ -z "${tag_list}" ]]; then
        echo -e ""
        echo -e "${gl_zi}【Git标签】${gl_lv}无${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_hong}错误：当前仓库不存在任何Git标签${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return 0
    fi
    echo -e "${gl_zi}>>> ${gl_huang}${current_dir_name} ${gl_zi}项目 ${gl_huang}Git ${gl_zi}标签 ${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"

    while IFS= read -r single_tag; do
        [[ -z "${single_tag}" ]] && continue
        print_single_tag "${single_tag}"
    done <<< "${tag_list}"

    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_all_full_tags