#include "dpi-bypass.h"
#include "hostlist.h"

extern struct Settings settings;
extern JNIEnv* jni_env;

//rapidjson::Document hostlist_document;
std::string hostlist_path;

bool find_in_hostlist(std::string host)
{
    std::string log_tag = "CPP/find_in_hostlist";

    // In VPN mode when connecting to https sites proxy server gets CONNECT requests to ip addresses
    // So if we receive ip address we need to find hostname for it

    // Check if host is IP
    struct sockaddr_in sa;
    int result = inet_pton(AF_INET, host.c_str(), &sa.sin_addr);
    if(settings.other.is_use_vpn && result != 0)
    {
        // Find class
        jclass localdnsserver_class = jni_env->FindClass("ru/evgeniy/dpitunnel/LocalDNSServer");
        if(localdnsserver_class == NULL)
        {
            log_error(log_tag.c_str(), "Failed to find LocalDNSServer class");
            return 0;
        }

        // Find Java method
        jmethodID localdnsserver_get_hostname = jni_env->GetStaticMethodID(localdnsserver_class, "getHostname", "(Ljava/lang/String;)Ljava/lang/String;");
        if(localdnsserver_get_hostname == NULL)
        {
            log_error(log_tag.c_str(), "Failed to find getHostname method");
            return 0;
        }

        // Call Java method
        jstring response_string_object = (jstring) jni_env->CallStaticObjectMethod(localdnsserver_class, localdnsserver_get_hostname, jni_env->NewStringUTF(host.c_str()));
        host = jni_env->GetStringUTFChars(response_string_object, 0);
        if(host.empty())
        {
            log_error(log_tag.c_str(), "Failed to find hostname to ip");
            return 0;
        }
    }

//    for(const auto & host_in_list : hostlist_document.GetArray())
//    {
//        if(host_in_list.GetString() == host) return 1;
//    }
    return 0;
}

int parse_hostlist()
{
    std::string log_tag = "CPP/parse_hostlist";

    // Open hostlist file
    std::ifstream hostlist_file;
    hostlist_file.open(hostlist_path);
    if(!hostlist_file)
    {
        log_error(log_tag.c_str(), "Failed to open hostlist file");
        return -1;
    }

    // Create string object from hostlist file
    std::stringstream hostlist_stream;
    hostlist_stream << hostlist_file.rdbuf();
    std::string hostlist_json = hostlist_stream.str();

    // Parse json object with rapidjson
//    if(hostlist_document.Parse(hostlist_json.c_str()).HasParseError())
//    {
//        log_error(log_tag.c_str(), "Failed to parse hostlist file");
//        return -1;
//    }

    return 0;
}

extern "C" JNIEXPORT void JNICALL Java_ru_evgeniy_dpitunnel_NativeService_setHostlistPath(JNIEnv* env, jobject obj, jstring HostlistPath)
{
    if(!HostlistPath) return;

    const char* hostlist_path_c = env->GetStringUTFChars(HostlistPath, NULL);
    if (!hostlist_path_c) return;
    const jsize len = env->GetStringUTFLength(HostlistPath);
    hostlist_path = std::string(hostlist_path_c, len);

    env->ReleaseStringUTFChars(HostlistPath, hostlist_path_c);
}