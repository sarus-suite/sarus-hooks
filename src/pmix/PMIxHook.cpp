#include "PMIxHook.hpp"

#include <sstream>
#include <boost/regex.hpp>

#include "libsarus/Error.hpp"
#include "libsarus/Utility.hpp"


namespace sarus {
namespace hooks {
namespace pmix {


void PMIxHook::activate() {
    libsarus::Logger::getInstance().setLevel(libsarus::LogLevel::INFO);

    log("Activating hook", libsarus::LogLevel::INFO);
    
    // Derive SlurmdSpoolDir and TmpFS.
    auto output = libsarus::process::executeCommand("scontrol show config");

    auto ss = std::stringstream{output};
    auto line = std::string{};
    auto matches = boost::smatch{};
    auto reSlurmdSpoolDir = boost::regex{"^SlurmdSpoolDir *= (.*)$"};
    auto reTmpFS = boost::regex{"^TmpFS *= (.*)$"};

    boost::filesystem::path pathSlurmdSpoolDir;
    boost::filesystem::path pathTmpFS;

    while (std::getline(ss, line)) {
        if (boost::regex_match(line, matches, reSlurmdSpoolDir)) {
            pathSlurmdSpoolDir = matches[1];
            log(boost::format("Successfully derived \"SlurmdSpoolDir=%s\"") % pathSlurmdSpoolDir.c_str(), libsarus::LogLevel::INFO);
        }
        
        if (boost::regex_match(line, matches, reTmpFS)) {
            pathTmpFS= matches[1];
            log(boost::format("Successfully derived \"TmpFS=%s\"") % pathTmpFS.c_str(), libsarus::LogLevel::INFO);
        }
    }

    log("Successful hook", libsarus::LogLevel::INFO);
}

void PMIxHook::log(const boost::format& message, libsarus::LogLevel level) const {
    log(message.str(), level);
}

void PMIxHook::log(const std::string& message, libsarus::LogLevel level) const {
    auto subsystemName = "pmix-hook";
    libsarus::Logger::getInstance().log(message, subsystemName, level);
}


}}} // closing namespaces

