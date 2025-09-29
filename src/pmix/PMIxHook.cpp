#include "PMIxHook.hpp"

#include <sstream>
#include <stdexcept>
#include <boost/regex.hpp>

#include "libsarus/Error.hpp"
#include "libsarus/Utility.hpp"


namespace sarus {
namespace hooks {
namespace pmix {


void PMIxHook::activate() {
    // NOTE: Setting PMIX_ environment variables inside a container will be done with CDI.

    libsarus::Logger::getInstance().setLevel(libsarus::LogLevel::INFO);
    log("Activating hook", libsarus::LogLevel::INFO);

    if (!checkRequirements()) {
        log("Hook requirements not satisfied. Skipping...", libsarus::LogLevel::INFO);
        return;
    }

    if (!checkPMIxSupport()) {
        log("No PMIx support. Skipping...", libsarus::LogLevel::INFO);
        return;
    }

    parseConfigJSONOfBundle();
    getSlurmIDs();
    derivePathsFromScontrol();
    mountPMIxDirectories();

    log("Successful hook", libsarus::LogLevel::INFO);
}

bool PMIxHook::checkRequirements() {
    log("Checking hook requirements...", libsarus::LogLevel::INFO);
    
    // Check if 'scontrol' is available.
    try {
        libsarus::process::executeCommand("which scontrol");
    } catch (...) {
        log("\"scontrol\" unavailable.", libsarus::LogLevel::INFO);
        return false;
    }

    log("Checked hook requirements", libsarus::LogLevel::INFO);
    
    return true;
}

bool PMIxHook::checkPMIxSupport() {
    log("Checking PMIx support...", libsarus::LogLevel::INFO);

    // Check if SLURM_MPI_TYPE is "pmix"-like.
    try {
        auto envSlurmMPIType = libsarus::environment::getVariable("SLURM_MPI_TYPE");
        if (envSlurmMPIType.substr(0, 4) != "pmix") {
            log(boost::format("SLURM_MPI_TYPE (%s) is not \"pmix*\"") % envSlurmMPIType, libsarus::LogLevel::INFO);
            return false;
        }
    } catch (...) {
        log("SLURM_MPI_TYPE undefined", libsarus::LogLevel::INFO);
        return false;
    }

    // Check if the environment actually contain "PMIX_*" variables
    std::string output;

    try {
        output = libsarus::process::executeCommand("env");
    } catch (...) {
        log("Cannot retrieve environment variables", libsarus::LogLevel::INFO);
        return false;
    }

    auto ss = std::stringstream{output};
    auto line = std::string{};

    bool hasPMIxVar = false;
    while (std::getline(ss, line)) {
        if (line.substr(0, 5) == "PMIX_") {
            hasPMIxVar = true;
            break;
        }
    }

    if (!hasPMIxVar) {
        log("No PMIX_* environment variable found", libsarus::LogLevel::INFO);
        return false;
    }

    log("Checked PMIx support", libsarus::LogLevel::INFO);

    return true;
}

void PMIxHook::parseConfigJSONOfBundle() {
    log("Parsing bundle config JSON...", libsarus::LogLevel::INFO);

    // Parse the bundle's JSON config. Code stolen from the old Sarus MPI hook.
    auto containerState = libsarus::hook::parseStateOfContainerFromStdin();
    auto json = libsarus::json::read(containerState.bundle() / "config.json");
    libsarus::hook::applyLoggingConfigIfAvailable(json);

    pathRootFS = boost::filesystem::path{ json["root"]["path"].GetString() };
    if (!pathRootFS.is_absolute())
        pathRootFS = containerState.bundle() / pathRootFS;

    log(boost::format("Parsed: pathRootFS: %s") % pathRootFS, libsarus::LogLevel::INFO);

    uid_t uidOfUser = json["process"]["user"]["uid"].GetInt();
    gid_t gidOfUser = json["process"]["user"]["gid"].GetInt();
    userIdentity = libsarus::UserIdentity(uidOfUser, gidOfUser, {});

    log(boost::format("Parsed: uid: %s, gid: %s") % uidOfUser % gidOfUser, libsarus::LogLevel::INFO);

    log("Parsed bundle config JSON", libsarus::LogLevel::INFO);
}

void PMIxHook::getSlurmIDs() {
    log("Getting Slurm IDs...", libsarus::LogLevel::INFO);

    try {
        envSlurmJobUID = libsarus::environment::getVariable("SLURM_JOB_UID");
    } catch (...) {
        // Respectfully ignore.
        envSlurmJobUID = "";
    }

    try {
        envSlurmJobID = libsarus::environment::getVariable("SLURM_JOB_ID");
        envSlurmStepID = libsarus::environment::getVariable("SLURM_STEP_ID");

        if (envSlurmJobID.empty() || envSlurmStepID.empty())
            SARUS_THROW_ERROR("Empty SLURM_JOB_ID or SLURM_STEP_ID");
    } catch (...) {
        SARUS_THROW_ERROR("Undefined SLURM_JOB_ID or SLURM_STEP_ID");
    }

    log("Got Slurm IDs", libsarus::LogLevel::INFO);
}

void PMIxHook::derivePathsFromScontrol() {
    log("Deriving paths from 'scontrol'...", libsarus::LogLevel::INFO);

    // Derive SlurmdSpoolDir and TmpFS from "scontrol".
    std::string output;

    try {
        output = libsarus::process::executeCommand("scontrol show config");
    } catch (...) {
        SARUS_THROW_ERROR("Unknown error while executing \"scontrol show config\"");
    }

    auto ss = std::stringstream{output};
    auto line = std::string{};
    auto matches = boost::smatch{};
    auto reSlurmdSpoolDir = boost::regex{"^SlurmdSpoolDir *= *([^ ]*).*"};
    auto reTmpFS = boost::regex{"^TmpFS *= *([^ ]*).*"};

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

    // Check the sanity of the derived paths.
    boost::system::error_code ec;

    if (!boost::filesystem::is_directory(pathSlurmdSpoolDir, ec)) {
        auto msg = boost::format("SlurmdSpoolDir is not a directory (%s)") % pathSlurmdSpoolDir;
        SARUS_THROW_ERROR(msg.str());
    }

    if (!boost::filesystem::is_directory(pathTmpFS, ec)) {
        auto msg = boost::format("TmpFS is not a directory (%s)") % pathTmpFS;
        SARUS_THROW_ERROR(msg.str());
    }

    log("Derived paths from 'scontrol'", libsarus::LogLevel::INFO);
}

void PMIxHook::mountPMIxDirectories() {
    log("Mounting PMIx directories...", libsarus::LogLevel::INFO);

    int mount_flags = MS_NOSUID | MS_NOEXEC | MS_NODEV | MS_PRIVATE;

    // Mount "spmix_appdir".
    auto pathAppdirUIDJobStep = pathTmpFS / "spmix_appdir";
    pathAppdirUIDJobStep += ("_" + envSlurmJobUID);
    pathAppdirUIDJobStep += ("_" + envSlurmJobID);
    pathAppdirUIDJobStep += ("." + envSlurmStepID);

    auto pathAppdirJobStep = pathTmpFS / "spmix_appdir";
    pathAppdirJobStep += ("_" + envSlurmJobID);
    pathAppdirJobStep += ("." + envSlurmStepID);

    if (!envSlurmJobUID.empty() && boost::filesystem::is_directory(pathAppdirUIDJobStep)) {
        try {
            libsarus::mount::validatedBindMount(pathAppdirUIDJobStep, pathAppdirUIDJobStep, userIdentity, pathRootFS, mount_flags);
            log(boost::format("Mounted spmix_appdir: %s") % pathAppdirUIDJobStep, libsarus::LogLevel::INFO);
        } catch (...) {
            // Respecfully ignore. ("nofail")
            log(boost::format("Cannot mount spmix_appdir: %s") % pathAppdirUIDJobStep, libsarus::LogLevel::INFO);
        }
    } else {
        try {
            libsarus::mount::validatedBindMount(pathAppdirJobStep, pathAppdirJobStep, userIdentity, pathRootFS, mount_flags);
            log(boost::format("Mounted spmix_appdir: %s") % pathAppdirJobStep, libsarus::LogLevel::INFO);
        } catch (...) {
            // Respecfully ignore. ("nofail")
            log(boost::format("Cannot mount spmix_appdir: %s") % pathAppdirJobStep, libsarus::LogLevel::INFO);
        }
    }

    // Mount "pmix".
    auto pathPMIxJobStep = pathSlurmdSpoolDir / "pmix";
    pathPMIxJobStep += ("." + envSlurmJobID);
    pathPMIxJobStep += ("." + envSlurmStepID);

    libsarus::mount::validatedBindMount(pathPMIxJobStep, pathPMIxJobStep, userIdentity, pathRootFS, mount_flags);
    log(boost::format("Mounted: %s") % pathPMIxJobStep, libsarus::LogLevel::INFO);

    log("Mounted PMIx directories", libsarus::LogLevel::INFO);
}

void PMIxHook::log(const boost::format& message, libsarus::LogLevel level) const {
    log(message.str(), level);
}

void PMIxHook::log(const std::string& message, libsarus::LogLevel level) const {
    auto subsystemName = "pmix-hook";
    libsarus::Logger::getInstance().log(message, subsystemName, level);
}


}}} // closing namespaces

