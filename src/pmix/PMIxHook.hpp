#ifndef sarus_hooks_pmix_PMIxHook_hpp
#define sarus_hooks_pmix_PMIxHook_hpp

#include <string>
#include <boost/filesystem.hpp>

#include "libsarus/Utility.hpp"
#include "libsarus/Logger.hpp"

namespace sarus {
namespace hooks {
namespace pmix {

class PMIxHook {
public:
    void activate();

private:
    void log(const boost::format& message, libsarus::LogLevel level) const; 
    void log(const std::string& message, libsarus::LogLevel level) const; 
};

}}} // closing namespaces

#endif
