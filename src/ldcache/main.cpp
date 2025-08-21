#include "LdCacheHook.hpp"
#include "libsarus/Error.hpp"
#include "libsarus/Logger.hpp"

int main(int argc, char* argv[]){
    try {
        sarus::hooks::ldcache::LdCacheHook{}.refresh();
	}
	catch (const libsarus::Error& e) {
	  libsarus::Logger::getInstance().logErrorTrace(e, "ldcache-hook");
	  return EXIT_FAILURE;
	}
	return 0;
}
