#include "dpi-bypass.h"
#include "packet.h"

extern struct Settings settings;

int parse_request(std::string request, std::string & method, std::string & host, int & port)
{
    // Extract method
    size_t method_end_position = request.find(" ");
    if(method_end_position == std::string::npos)
    {
        return -1;
    }
    method = request.substr(0, method_end_position);

    // Extract hostname an port if exists
    std::string regex_string = "[-a-zA-Z0-9@:%._\\+~#=]{2,256}\\.[-a-z0-9]{1,16}(:[0-9]{1,5})?";
    std::regex url_find_regex(regex_string);
    std::smatch match;

    if(std::regex_search(request, match, url_find_regex) == 0)
    {
        return -1;
    }

    // Get string from regex output
    std::string found_url = match.str(0);

    // Remove "www." if exists
    size_t www = found_url.find("www.");
    if(www != std::string::npos)
    {
        found_url.erase(www, 4);
    }

    // Check if port exists
    size_t port_start_position = found_url.find(":");
    if(port_start_position == std::string::npos)
    {
        // If no set deafult port
        if(method == "CONNECT")	port = 443;
        else port = 80;
        host = found_url;
    }
    else
    {
        // If yes extract port
        port = std::stoi(found_url.substr(port_start_position + 1, found_url.size() - port_start_position));
        host = found_url.substr(0, port_start_position);
    }

    return 0;
}

void modify_http_request(std::string & request, bool hostlist_condition)
{
    std::string log_tag = "CPP/modify_http_request";

    if(request.empty()) return;

    // First of all remove url in first string of request if need
    // We mustn't do it when user enabled "Use HTTP proxy" mode
    if(!settings.http.is_use_http_proxy)
    {
        std::string regex_string = "(https?://)?[-a-zA-Z0-9@:%._\\+~#=]{2,256}\\.[-a-z0-9]{2,16}(:[0-9]{1,5})?";
        std::regex url_find_regex(regex_string);
        std::smatch match;
        if(std::regex_search(request, match, url_find_regex) == 0)
        {
            log_error(log_tag.c_str(), "Failed to remove url, while modifying request");
            return;
        }

        // Get string from regex output
        std::string found_url = match.str(0);
        request.replace(request.find(found_url), found_url.size(), "");
    }

    size_t host_header_position = request.find("Host:");
    if(host_header_position == std::string::npos)
    {
        log_error(log_tag.c_str(), "Failed to find Host: header");
        return;
    }

    // Change host spell if need
    if(hostlist_condition && settings.http.is_change_host_header)
    {
        request.replace(host_header_position, settings.http.host_header.size(), settings.http.host_header);
    }

    // Add dot after hostname if need
    if(hostlist_condition && settings.http.is_add_dot_after_host)
    {
        size_t host_header_end = request.find(std::string("\r\n"), host_header_position);
        if(host_header_end != std::string::npos)
        {
            request.insert(host_header_end, ".");
        }
        else
        {
            log_error(log_tag.c_str(), "Failed to add dot after hostname");
        }
    }

    // Add tab after hostname if need
    if(hostlist_condition && settings.http.is_add_tab_after_host)
    {
        size_t host_header_end = request.find(std::string("\r\n"), host_header_position);
        if(host_header_end != std::string::npos)
        {
            request.insert(host_header_end, "\t");
        }
        else
        {
            log_error(log_tag.c_str(), "Failed to add tab after hostname");
        }
    }

    // Remove space after host header if need
    if(hostlist_condition && settings.http.is_remove_space_after_host)
    {
        request.erase(host_header_position + 5, 1);
    }

    size_t method_end_position = request.find(" ");

    // Add space after method if need
    if(hostlist_condition && settings.http.is_add_space_after_method)
    {
        request.insert(method_end_position, " ");
    }

    // Add newline symbol before method if need
    if(hostlist_condition && settings.http.is_add_newline_before_method)
    {
        request.insert(0, "\r\n");
    }

    // Replace all dos newlines(\r\n) with unix style newlines(\n)
    if(hostlist_condition && settings.http.is_use_unix_newline)
    {
        size_t current_dos_newline = 0;
        while(true)
        {
            current_dos_newline = request.find(std::string("\r\n"), current_dos_newline);
            if(current_dos_newline == std::string::npos) break;
            request.erase(current_dos_newline + 1, 1);
        }
    }
}