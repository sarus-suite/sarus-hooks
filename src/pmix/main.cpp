#include "PMIxHook.hpp"
#include "libsarus/Error.hpp"
#include "libsarus/Logger.hpp"
#include <cstring>

int main(int argc, char* argv[]){
    // TODO: remove this once we start to use 'precreate' hooks.
    if (argc == 2 && &argv[1] != NULL && !strcmp(argv[1], "--config")) {
        sarus::hooks::pmix::PMIxHook{}.printConfig();
        return 0;
    }

    try {
        sarus::hooks::pmix::PMIxHook{}.activate();
	}
	catch (const libsarus::Error &e) {
	    libsarus::Logger::getInstance().logErrorTrace(e, "pmix-hook");
	    exit(EXIT_FAILURE);
	}
	return 0;
}
