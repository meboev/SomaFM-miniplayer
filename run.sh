#!/bin/bash
./uninstall.sh ; ./build.sh && ./create-dmg.sh && ./install.sh && sleep 1 && ./start.sh
