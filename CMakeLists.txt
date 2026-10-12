cmake_minimum_required(VERSION 3.20)

project(
    BakalariPlasmaWidget
    VERSION 0.1.0
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

include(GNUInstallDirs)

set(PLASMOID_ID
    "cz.saruman.bakalari"
)

set(PLASMOID_INSTALL_DIR
    "${CMAKE_INSTALL_DATADIR}/plasma/plasmoids/${PLASMOID_ID}"
)

# ----------------------------
# Dependencies
# ----------------------------

find_package(
    Qt6 REQUIRED
    COMPONENTS
        Core
        Qml
)

find_package(
    KF6Wallet REQUIRED
)

# ----------------------------
# KWallet QML plugin
# ----------------------------

add_library(
    bakalarwalletplugin
    SHARED

    wallet/walletbackend.cpp
    wallet/walletbackend.h
    wallet/walletplugin.cpp
)

target_link_libraries(
    bakalarwalletplugin
    PRIVATE
        Qt6::Core
        Qt6::Qml
        KF6::Wallet
)

set_target_properties(
    bakalarwalletplugin
    PROPERTIES
        PREFIX "lib"
)

# ----------------------------
# Install plasmoid files
# ----------------------------

install(
    DIRECTORY
        package/
    DESTINATION
        "${PLASMOID_INSTALL_DIR}"

    # Old development/generated timetable files
    # must not be distributed.
    PATTERN "contents/data/timetable.json" EXCLUDE
    PATTERN "contents/data/timetable.js" EXCLUDE

    # The plugin is installed separately below.
    PATTERN "contents/ui/BakalariWallet/*.so" EXCLUDE
)

# ----------------------------
# Install KWallet QML module
# ----------------------------

install(
    TARGETS
        bakalarwalletplugin

    LIBRARY DESTINATION
        "${PLASMOID_INSTALL_DIR}/contents/ui/BakalariWallet"
)

install(
    FILES
        wallet/qmldir

    DESTINATION
        "${PLASMOID_INSTALL_DIR}/contents/ui/BakalariWallet"
)