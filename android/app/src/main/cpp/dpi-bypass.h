#ifndef DPITUNNEL_DPI_BYPASS_H
#define DPITUNNEL_DPI_BYPASS_H

#include <iostream>
#include <vector>
#include <string>
#include <cstring>
#include <regex>
#include <fstream>
#include <sstream>

#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#include <unistd.h>
//
//#include <rapidjson/document.h>
//#include <rapidjson/prettywriter.h>
#include <jni.h>
#include <android/log.h>

#define  log_debug(...)  __android_log_print(ANDROID_LOG_DEBUG, __VA_ARGS__)
#define  log_error(...)  __android_log_print(ANDROID_LOG_ERROR, __VA_ARGS__)

struct Settings
{
    struct
    {
        bool is_use_split;
        unsigned int split_position;
        bool is_use_socks5;
        bool is_use_http_proxy;
    } https;

    struct
    {
        bool is_use_split;
        unsigned int split_position;
        bool is_change_host_header;
        std::string host_header;
        bool is_add_dot_after_host;
        bool is_add_tab_after_host;
        bool is_remove_space_after_host;
        bool is_add_space_after_method;
        bool is_add_newline_before_method;
        bool is_use_unix_newline;
        bool is_use_socks5;
        bool is_use_http_proxy;
    } http;

    struct
    {
        bool is_use_doh;
        bool is_use_doh_only_for_site_in_hostlist;
        std::string dns_doh_servers;
    } dns;

    struct
    {
        bool is_use_hostlist;
        std::string socks5_server;
        std::string http_proxy_server;
        int bind_port;
        bool is_use_vpn;
    } other;
};

#endif //DPITUNNEL_DPI_BYPASS_H
