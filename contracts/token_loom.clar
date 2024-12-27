;; TokenLoom - NFT-based story arc platform
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-token (err u102))
(define-constant err-chapter-already-linked (err u103))

;; Data Variables
(define-data-var last-token-id uint u0)

;; Data Maps
(define-map chapters
    uint 
    {
        title: (string-ascii 100),
        content: (string-utf8 1000),
        author: principal,
        next-chapter: (optional uint)
    }
)

(define-map story-arcs 
    uint 
    {
        title: (string-ascii 100),
        first-chapter: uint,
        contributors: (list 10 principal)
    }
)

;; NFT Setup
(define-non-fungible-token chapter uint)

;; Mint new chapter
(define-public (mint-chapter (title (string-ascii 100)) (content (string-utf8 1000)))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (try! (nft-mint? chapter token-id tx-sender))
        (map-set chapters token-id {
            title: title,
            content: content,
            author: tx-sender,
            next-chapter: none
        })
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

;; Link chapters
(define-public (link-chapters (chapter-id uint) (next-chapter-id uint))
    (let
        (
            (chapter (unwrap! (map-get? chapters chapter-id) (err err-invalid-token)))
        )
        (asserts! (is-eq tx-sender (get author chapter)) (err err-not-token-owner))
        (asserts! (is-none (get next-chapter chapter)) (err err-chapter-already-linked))
        (map-set chapters chapter-id (merge chapter {next-chapter: (some next-chapter-id)}))
        (ok true)
    )
)

;; Create story arc
(define-public (create-story-arc (title (string-ascii 100)) (first-chapter uint))
    (let
        (
            (arc-id (+ (var-get last-token-id) u1))
        )
        (try! (nft-mint? chapter arc-id tx-sender))
        (map-set story-arcs arc-id {
            title: title,
            first-chapter: first-chapter,
            contributors: (list tx-sender)
        })
        (var-set last-token-id arc-id)
        (ok arc-id)
    )
)

;; Add contributor to story arc
(define-public (add-contributor (arc-id uint) (contributor principal))
    (let
        (
            (arc (unwrap! (map-get? story-arcs arc-id) (err err-invalid-token)))
        )
        (asserts! (is-eq tx-sender (get author (unwrap! (map-get? chapters (get first-chapter arc)) (err err-invalid-token)))) (err err-not-token-owner))
        (map-set story-arcs arc-id (merge arc {contributors: (unwrap! (as-max-len? (append (get contributors arc) contributor) u10) (err u104))}))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-chapter (chapter-id uint))
    (map-get? chapters chapter-id)
)

(define-read-only (get-story-arc (arc-id uint))
    (map-get? story-arcs arc-id)
)

;; NFT trait implementation
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) (err err-not-token-owner))
        (nft-transfer? chapter token-id sender recipient)
    )
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? chapter token-id))
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)