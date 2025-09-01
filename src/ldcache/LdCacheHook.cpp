#include "LdCacheHook.hpp"

#include "libsarus/Error.hpp"
#include "libsarus/Utility.hpp"


namespace sarus {
namespace hooks {
namespace ldcache {


void LdCacheHook::activate() {
    log("Activating hook", libsarus::LogLevel::INFO);

    containerState = libsarus::hook::parseStateOfContainerFromStdin();

    parseConfigJSONOfBundle();   // get rootfsDir
    parseEnvironmentVariables(); // get ldconfigPath

    // run and collect output into logs
    if (!ldconfigPath.empty()) {
        log("Updating dynamic linker cache", libsarus::LogLevel::INFO);

        std::string command = ldconfigPath.string() + " -v -r " + rootfsDir.string();
        log("cmd=" + command, libsarus::LogLevel::DEBUG);

        std::string output = libsarus::process::executeCommand(command);

        log("ldconfig_output_begin\n" + output + "ldconfig_output_end",
        libsarus::LogLevel::DEBUG);
    }

    // Output summary
    using fs = boost::filesystem;

    boost::filesystem::path cache = rootfsDir / "etc/ld.so.cache";

    bool cacheExists = fs::exists(cache);
    std::uintmax_t cacheSize = cacheExists ? fs::file_size(cache) : 0;
    std::time_t cacheMtime = cacheExists ? fs::last_write_time(cache) : 0;

    std::string summary = (boost::format(
        "summary rootfs=%1% cache_exists=%2% cache_size=%3% cache_mtime=%4%")
        % rootfsDir.string()
        % cacheExists
        % cacheSize
        % cacheMtime).str();

    log(summary, libsarus::LogLevel::INFO);

    log("Successful hook", libsarus::LogLevel::INFO);
}


void LdCacheHook::parseConfigJSONOfBundle() {
    log("Parsing JSON of bundle", libsarus::LogLevel::INFO);

    auto json = libsarus::json::read(containerState.bundle() / "config.json");
    libsarus::hook::applyLoggingConfigIfAvailable(json);

    auto root = boost::filesystem::path{ json["root"]["path"].GetString() };
    rootfsDir = root.is_absolute() ? root : (containerState.bundle() / root);

    log("Success parsing config.json", libsarus::LogLevel::INFO);
}


void LdCacheHook::parseEnvironmentVariables() {
    log("Parsing environment variables", libsarus::LogLevel::INFO);

    try {
        ldconfigPath = libsarus::environment::getVariable("LDCONFIG_PATH");

        log("Success parsing LDCONFIG_PATH", libsarus::LogLevel::INFO);
    }
    catch (const libsarus::Error&) {
        log("LDCONFIG_PATH not set. Using default ldconfig", libsarus::LogLevel::INFO);
        ldconfigPath = "ldconfig";
    }
}


void LdCacheHook::log(const std::string &msg, libsarus::LogLevel lvl) const{
    libsarus::Logger::getInstance().log(msg, "ldcache-hook", lvl);
}


}}} // closing namespaces

