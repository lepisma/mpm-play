;; Youtube caching module

(import pafy)
(import os)
(import [os.path :as path])
(require [high.macros [*]])

(defclass Ytcache []
  "Cache youtube songs in a local directory"

  (defn --init-- [self cache-path size]
    (setv self.cache-path cache-path)
    (setv self.size size)
    (self.init-listing))

  (defn init-listing [self]
    (let [files (os.listdir self.cache-path)]
      (setv self.cache-list files)))

  (defn save-in-cache [self stream file-name]
    "Download file in cache. Ignoring limit as of now."
    (let [file-path (path.join self.cache-path file-name)]
      (thread-run
       (.download stream
                  :quiet True
                  :filepath file-name))))

  (defn get-playable-url [self song]
    "Return playable url."
    (let [song-id (str (get song "id"))
          ytid (nth (.split (get song "url") ":") 1)]
      (if (in song-id self.cache-list)
        (path.join self.cache-path song-id)
        (let [stream (.getbestaudio (pafy.new ytid :basic False))]
          ;; Start thread for downloading song and return
          ;; the stream url
          (self.save-in-cache stream song-id)
          stream.url)))))
