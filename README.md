# RepoSync

Licensed under MIT, feel free to make any repo backed up.

---

```
Usage: ./RepoSync <url> <output dir> [Options]

Options:

    We default only update packages that are not
    exists and only download 1 newest version
    each for each package
    This is suggested avoiding waste of server
    or network resources
    It is expensive to host a cloud machine

    --depth     default to 2, used to control how
                may versions of a package should be
                downloaded if they exists. the count
                excluded they versions that exists
                locally
                set to 0 to download them all
    --timeout   default to 30, used to control timeout
                time for each package download session
    --udid      udid to request, ignored if --mess
                random if not set
    --ua        user agent to request, cydia if not set
    --machine   machine to request, default to
                "iPhone8,1", ignored if --mess
    --firmware  system version to request, default to
                "13.0", ignored if --mess
    --overwrite default to false, will download all
                packages and overwrite them for no
                reason even they already exists
    --clean     enable clean will delete all your local
                files in output dir first
    --skip-sum  shutdown package validation even if
                there is check sum or other sum info
                exists in package release file
    --mess      generate random id for each request
    --timegap   sleep several seconds between requests
                default to 0 and disabled
                some repo has limited request to 10/min
                ^_^

Examples:

    ./RepoSync https://repo.test.cn ./out \
        --depth=4 \
        --timeout=60 \
        --udid=arandomudidnumber \
        --ua=someUAyouwant2use \
        --machine=iPhone9,2 \
        --firmware=12.0.0 \
        --overwrite \
        --skip-sum \
        --mess \
        --timegap=1 \
        --clean

```

2020.4.12 Lakr Aream