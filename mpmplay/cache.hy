;; Youtube caching module

(import pafy)
(import os)
(import [os.path :as path])
(require [high.macros [*]])

(defn get-yt-stream-url [ytid]
  (let [pf (pafy.new ytid :basic False)
        audio (pf.getbestaudio)]
    audio.url))

(defclass Ytcache []
  "Cache youtube songs in a local directory"

  (defn --init-- [self cache-path size]
    (setv self.cache-path cache-path)
    (setv self.size size)
    (self.init-listing))

  (defn init-listing [self]
    (let [files (os.listdir self.cache-path)]
      (setv self.cache-list files)))

  (defn download [self song]
    "Download file in cache. Ignoring limit as of now.")

  (defn get-playable-url [self song]
    "Return playable url."
    (let [song-id (get song "id")
          url (get song "url")]
      (if (in song-id self.cache-list)
        (path.join self.cache-path song-id)
        (let [ytid (nth (.split url ":") 1)]
         (self.download song)
         (get-yt-stream-url ytid))))))
