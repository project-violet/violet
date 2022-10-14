#ifndef DPITUNNEL_PACKET_H
#define DPITUNNEL_PACKET_H

int parse_request(std::string request, std::string & method, std::string & host, int & port);
void modify_http_request(std::string & request, bool hostlist_condition);

#endif //DPITUNNEL_PACKET_H
