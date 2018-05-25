;; Youtube caching module

(import pafy)
(import os)
(import [os.path :as path])
(import [high.utils [*]])
(require [high.macros [*]])
(import requests)
(import [eep [Searcher]])

(defn search-yt [search-term]
  "Search for term in youtube and return first youtube url"
  (let [params (dict :search_query search-term)
        res (requests.get "https://youtube.com/results" :params params)
        es (Searcher res.text)]
       (es.search-forward "watch?v=")
       (es.jump 11)
       (+ "https://youtube.com/" (es.get-sub))))

(defn first-hit-url [song]
  "Return a playable stream using the first hit data"
  (let [yturl (search-yt (+ (get song "title") " " (get song "artist")))
        stream (.getbestaudio (pafy.new :url yturl :basic False))]
       stream.url))

(defclass Ytcache []
  "Cache youtube songs in a local directory"

  (defn --init-- [self cache-path]
    (setv self.cache-path cache-path)
    (ensure-dir cache-path)
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
                  :filepath file-path))
      (self.cache-list.append file-name)))

  (defn get-playable-url [self song]
    "Return playable url."
    (let [song-id (str (get song "id"))
          ytid (nth (.split (get song "url") ":") 1)]
      (if (in song-id self.cache-list)
        (path.join self.cache-path song-id)
        (let [stream (.getbestaudio (pafy.new ytid :basic False))]
          ;; Start thread for downloading song and return the stream url
          (self.save-in-cache stream song-id)
          stream.url)))))
