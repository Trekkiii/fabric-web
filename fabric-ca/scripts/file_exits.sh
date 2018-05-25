#!/usr/bin/expect

# 判断远程服务器中的文件是否存在

# 错误码：
#   0：存在
#   1：不存在
#   2：密码错误

if {$argc < 4} {
    send_user "Usage: $argv0 <remote_user> <remote_host> <remote_pwd> <remote_file>"
    exit -1
}

set timeout -1

set remote_user [lindex $argv 0] ;# 远程服务器用户名
set remote_host [lindex $argv 1] ;# 远程服务器域名
set remote_pwd [lindex $argv 2] ;# 远程服务器密码
set remote_file [lindex $argv 3] ;# 远程服务器文件

set passwd_error 0

spawn ssh ${remote_user}@${remote_host} "test -e ${remote_file} && echo 'File exists' || echo 'File Not exists'"

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
    "File exists" {
        exit 0
    }
    "File Not exists" {
        exit 1
    }
}