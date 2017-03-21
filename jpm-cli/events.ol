/**
 * @input .name: string
 * @output .exitCode: int
 */
define EventHandle {
    ns -> EventHandle;
    pkgInfo@JPM()(ns.package);
    if (is_defined(ns.package.events.(ns.in.name))) {
        ns.eventReq.directory = context;
        ns.eventReq.suppress = false;
        split@StringUtils(ns.package.events.(ns.in.name) {
            .regex = " "
        })(ns.split);
        ns.eventReq.commands -> ns.split.result;
        execute@Execution(ns.eventReq)(ns.out.exitCode);

        if (EventHandle.out.exitCode != 0) {
            throw(CLIFault, {
                .type = FAULT_BAD_REQUEST,
                .message = "Script for '" + EventHandle.in.name + "' " +
                    "exited with a non-zero status code (" +
                    EventHandle.out.exitCode + ")"
            })
        }
    }
}

