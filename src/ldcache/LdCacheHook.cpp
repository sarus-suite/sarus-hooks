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

    if (!ldconfigPath.empty()) {
	    log("Updating dynamic linker cache", libsarus::LogLevel::INFO);

		libsarus::process::executeCommand(ldconfigPath.string() + " -v -r " + rootfsDir.string());
	}

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
