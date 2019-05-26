;; Hook related functions

(import [subprocess [Popen]])
(import [os [environ]])
(require [high.macros [*]])

(defn run-cmd [cmd]
  (Popen [cmd] :shell True :executable (get environ "SHELL")))

(defn run-hook [hook-name config]
  "Run the given hook, taking script from the config"
  (let [hooks (get config "hooks")]
    (if (in hook-name hooks)
        (run-cmd (get hooks hook-name)))))
