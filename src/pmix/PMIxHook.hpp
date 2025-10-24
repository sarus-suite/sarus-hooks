#ifndef sarus_hooks_pmix_PMIxHook_hpp
#define sarus_hooks_pmix_PMIxHook_hpp

#include <string>
#include <boost/filesystem.hpp>

#include "libsarus/Utility.hpp"
#include "libsarus/Logger.hpp"
#include "libsarus/UserIdentity.hpp"

namespace sarus {
namespace hooks {
namespace pmix {

class PMIxHook {
public:
    void printConfig() const;
    void activate();

private:
    bool checkRequirements();
    bool checkPMIxSupport();
    void parseConfigJSONOfBundle();
    void getSlurmIDs();
    void derivePathsFromScontrol();
    void mountPMIxDirectories();

    void log(const boost::format& message, libsarus::LogLevel level) const; 
    void log(const std::string& message, libsarus::LogLevel level) const; 

    std::string envSlurmJobUID;
    std::string envSlurmJobID;
    std::string envSlurmStepID;
    boost::filesystem::path pathRootFS;
    boost::filesystem::path pathSlurmdSpoolDir;
    boost::filesystem::path pathTmpFS;
    libsarus::UserIdentity userIdentity;
};

}}} // closing namespaces

#endif
