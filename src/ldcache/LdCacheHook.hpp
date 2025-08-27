#ifndef sarus_hooks_ldcache_LdCacheHook_hpp
#define sarus_hooks_ldcache_LdCacheHook_hpp

#include <string>
#include <boost/filesystem.hpp>

#include "libsarus/Utility.hpp"
#include "libsarus/Logger.hpp"

namespace sarus {
namespace hooks {
namespace ldcache {

class LdCacheHook {
public:
    void activate();

private:
    void parseConfigJSONOfBundle();
    void parseEnvironmentVariables();
    void log(const std::string& msg, libsarus::LogLevel lvl) const;

private:
    libsarus::hook::ContainerState containerState;
	boost::filesystem::path rootfsDir;
    boost::filesystem::path ldconfigPath;
};

}}} // closing namespaces

#endif
