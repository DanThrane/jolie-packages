joliedev \
    --pkg registry,.,registry.ol \
    --pkg authorization,jpm_packages/authorization,main.ol \
    --pkg checksum,jpm_packages/checksum \
    --pkg packages,jpm_packages/packages,main.ol \
    --pkg registry-database,jpm_packages/registry-database,main.ol \
    --pkg sqlite,jpm_packages/sqlite \
    --pkg bcrypt,jpm_packages/bcrypt \
    --pkg jpm-utils,jpm_packages/jpm-utils \
    --pkg pkg,jpm_packages/pkg \
    --pkg semver,jpm_packages/semver \
    --conf reg-development config.col \
    registry.pkg
