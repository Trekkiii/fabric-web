#!/usr/bin/expect

# SCP远程拷贝
#
# 错误码：
#   -1：语法错误
#   0：拷贝成功
#   1：拷贝失败，文件不存在
#   2：密码错误

if {$argc < 6} {
    send_user "Usage: $argv0 <remote_user> <remote_host> <remote_pwd> <remote_file> <local_file> <to|from>"
    exit -1
}

set timeout -1

set remote_user [lindex $argv 0] ;# 远程服务器用户名
set remote_host [lindex $argv 1] ;# 远程服务器域名
set remote_pwd [lindex $argv 2] ;# 远程服务器密码
set remote_file [lindex $argv 3] ;# 远程服务器文件
set local_file [lindex $argv 4] ;# 保存的本地文件
set direction [lindex $argv 5] ;# 拷贝的方向，可选值：from、to

set passwd_error 0

if { ${direction} == "from" } {
    spawn scp -r ${remote_user}@${remote_host}:${remote_file} ${local_file}
} elseif { ${direction} == "to" } {
    spawn scp -r ${local_file} ${remote_user}@${remote_host}:${remote_file}
} else {
    send_user "Usage: $argv0 <remote_user> <remote_host> <remote_pwd> <remote_file> <local_file> <to|from>"
    exit -1
}

expect {

    "*assword:" {
        if { ${passwd_error} == 1 } {
            send_user "Password is wrong!~\n"
            exit 2
        }
        set passwd_error 1
        send "${remote_pwd}\n"
        exp_continue
    }
    "*es/no)?*" {
        send "yes\n"
        exp_continue
    }
    eof {
        catch wait result;
        exit [lindex $result 3]
    }
}