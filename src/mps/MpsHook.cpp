#include <cstdlib>
#include <string>
#include <iostream>
#include <boost/filesystem.hpp>
#include <boost/format.hpp>

#include "libsarus/Logger.hpp"
#include "libsarus/Error.hpp"
#include "libsarus/Utility.hpp"
#include "libsarus/Process.hpp"
#include "libsarus/HookUtility.hpp"
#include "libsarus/Json.hpp"

namespace fs = boost::filesystem;

static void log(const std::string& msg, libsarus::LogLevel lvl=libsarus::LogLevel::INFO) {
    libsarus::Logger::getInstance().log(msg, "mps-hook", lvl);
}

static std::string getEnvOr(const char* key, const std::string& def="") {
    const char* p = std::getenv(key);
    return p ? std::string{p} : def;
}

static bool mpsRunning() {
    int status = libsarus::process::executeCommandWithStatus("pidof nvidia-cuda-mps-control");
    return status == 0;
}

static void ensureDir(const fs::path& p) {
    if(!fs::exists(p)) {
        fs::create_directories(p);
    }
}

int main(int argc, char** argv) {
    // Parse container state + bundle config to enable standard logging
    auto state = libsarus::hook::parseStateOfContainerFromStdin();
    auto json = libsarus::json::read(state.bundle() / "config.json");
    libsarus::hook::applyLoggingConfigIfAvailable(json);
    log("MPS hook invoked");

    // Reading the action
    std::string action = "start";
    for(int i=1;i<argc;i++){
        std::string a = argv[i];
        if(a.rfind("--action=",0)==0) {
            action = a.substr(std::string("--action=").size());
        }
    }

    // From hook configuration env
    std::string pipeDir = getEnvOr("CUDA_MPS_PIPE_DIRECTORY", "/var/run/nvidia-mps");
    if(pipeDir.empty()){
        log("CUDA_MPS_PIPE_DIRECTORY is empty, nothing to do", libsarus::LogLevel::WARNING);
        return 0;
    }

    log((boost::format("Using CUDA_MPS_PIPE_DIRECTORY=%1%") % pipeDir).str(), libsarus::LogLevel::DEBUG);
    ensureDir(fs::path(pipeDir));

    if(action == "start") {
        if(mpsRunning()) {
            log("MPS already running; skipping start", libsarus::LogLevel::INFO);
            return 0;
        }
        std::string cmd = "CUDA_MPS_PIPE_DIRECTORY=\"" + pipeDir + "\" nvidia-cuda-mps-control -d";
        log("Starting MPS: " + cmd, libsarus::LogLevel::INFO);
        std::string out = libsarus::process::executeCommand(cmd);
        log("Started MPS", libsarus::LogLevel::INFO);
    }
    else if(action == "stop") {
        if(!mpsRunning()) {
            log("MPS not running; nothing to stop", libsarus::LogLevel::INFO);
            return 0;
        }
        std::string cmd = "CUDA_MPS_PIPE_DIRECTORY=\"" + pipeDir + "\" sh -lc 'echo quit | nvidia-cuda-mps-control'";
        log("Stopping MPS", libsarus::LogLevel::INFO);
        std::string out = libsarus::process::executeCommand(cmd);
        log("Stopped MPS", libsarus::LogLevel::INFO);
    }
    else {
        log("Unknown --action= " + action, libsarus::LogLevel::ERROR);
        return 1;
    }

    log("MPS hook finished", libsarus::LogLevel::INFO);
    return 0;
}

