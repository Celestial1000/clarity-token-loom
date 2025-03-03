;; TokenLoom - NFT-based story arc platform
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-token (err u102))
(define-constant err-chapter-already-linked (err u103))
(define-constant err-content-too-long (err u104))
(define-constant err-invalid-operation (err u105))
(define-constant err-contract-paused (err u106))
(define-constant err-not-contributor (err u107))
(define-constant err-contributor-limit (err u108))
(define-constant err-invalid-metadata (err u109))

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var contract-paused bool false)

;; Data Maps
(define-map chapters
    uint 
    {
        title: (string-ascii 100),
        content: (string-utf8 1000),
        author: principal,
        next-chapter: (optional uint),
        version: uint,
        previous-versions: (list 5 (string-utf8 1000))
    }
)

(define-map story-arcs 
    uint 
    {
        title: (string-ascii 100),
        first-chapter: uint,
        contributors: (list 10 principal),
        metadata: (optional (string-utf8 500))
    }
)

;; NFT Setup
(define-non-fungible-token chapter uint)

;; Admin Functions
(define-public (set-contract-pause (paused bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
        (ok (var-set contract-paused paused))
    )
)

;; Chapter Management Functions
(define-public (mint-chapter (title (string-ascii 100)) (content (string-utf8 1000)))
    (begin
        (asserts! (not (var-get contract-paused)) (err err-contract-paused))
        (asserts! (<= (len content) u1000) (err err-content-too-long))
        (let
            (
                (token-id (+ (var-get last-token-id) u1))
            )
            (try! (nft-mint? chapter token-id tx-sender))
            (map-set chapters token-id {
                title: title,
                content: content,
                author: tx-sender,
                next-chapter: none,
                version: u1,
                previous-versions: (list)
            })
            (var-set last-token-id token-id)
            (print {event: "chapter-minted", token-id: token-id, author: tx-sender})
            (ok token-id)
        )
    )
)

;; Update chapter content
(define-public (update-chapter-content (chapter-id uint) (new-content (string-utf8 1000)))
    (begin
        (asserts! (not (var-get contract-paused)) (err err-contract-paused))
        (let
            (
                (chapter (unwrap! (map-get? chapters chapter-id) (err err-invalid-token)))
            )
            (asserts! (is-eq tx-sender (get author chapter)) (err err-not-token-owner))
            (asserts! (<= (len new-content) u1000) (err err-content-too-long))
            (map-set chapters chapter-id (merge chapter {
                content: new-content,
                version: (+ (get version chapter) u1),
                previous-versions: (unwrap-panic (as-max-len? 
                    (append (get previous-versions chapter) (get content chapter))
                    u5
                ))
            }))
            (print {event: "chapter-updated", chapter-id: chapter-id, version: (+ (get version chapter) u1)})
            (ok true)
        )
    )
)

;; Story Arc Management Functions
(define-public (add-contributor (arc-id uint) (contributor principal))
    (let
        (
            (arc (unwrap! (map-get? story-arcs arc-id) (err err-invalid-token)))
        )
        (asserts! (is-eq tx-sender (get author (unwrap! (map-get? chapters (get first-chapter arc)) (err err-invalid-token)))) (err err-not-token-owner))
        (asserts! (<= (len (get contributors arc)) u9) (err err-contributor-limit))
        (map-set story-arcs arc-id (merge arc {
            contributors: (unwrap-panic (as-max-len? 
                (append (get contributors arc) contributor)
                u10
            ))
        }))
        (print {event: "contributor-added", arc-id: arc-id, contributor: contributor})
        (ok true)
    )
)

;; [Previous functions remain unchanged...]

;; Enhanced transfer function
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-some (nft-get-owner? chapter token-id)) (err err-invalid-token))
        (asserts! (is-eq tx-sender sender) (err err-not-token-owner))
        (try! (nft-transfer? chapter token-id sender recipient))
        (print {event: "token-transferred", token-id: token-id, sender: sender, recipient: recipient})
        (ok true)
    )
)
