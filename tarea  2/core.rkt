#lang play

(print-only-errors #t)

(require "env.rkt")

;; log global
(define log (box '()))

;; parametro
(define print-par (make-parameter println))

;; resultados
(deftype Result
  (result val log))

;; println-g :: num -> Null
;; agrega el numero al log global
(define (println-g n)
  (set-box! log (cons n (unbox log))))

;; register :: log -> num -> Null
;; recibe un log local y un numero, y registra la impresion del numero en el log local
(define (register log-local)
  (lambda (n)
    (set-box! log-local (cons n (unbox log-local)))))

#|
<CL> ::= <num>
         | {+ <CL> <CL>}
         | {if0 <CL> <CL> <CL>}
         | {with {<sym> <CL>} <CL>}
         | <id>
         | {<CL> <CL>}
         | {fun {<sym>} <CL>}
         | {printn <CL>}
|#
(deftype CL
  (num n)
  (add l r)
  (if0 c t f)
  (fun id body)
  (id s)
  (app fun-expr arg-expr)
  (printn e))

;; parse :: s-expr -> CL
(define (parse-cl s-expr)
  (match s-expr
    [(? number?) (num s-expr)]
    [(? symbol?) (id s-expr)]
    [(list '+ l r) (add (parse-cl l) (parse-cl r))]
    [(list 'if0 c t f) (if0 (parse-cl c)
                            (parse-cl t)
                            (parse-cl f))]
    [(list 'with (list x e) b)
     (app (fun x (parse-cl b)) (parse-cl e))]
    [(list 'fun (list x) b) (fun x (parse-cl b))]
    [(list 'printn e) (printn (parse-cl e))]
    [(list f a) (app (parse-cl f) (parse-cl a))]))

;; values
(deftype Val
  (numV n)
  (closV id body env))

;; interp :: Expr Env -> Val
(define (interp expr env)
  (match expr
    [(num n) (numV n)]
    [(fun id body) (closV id body env)]
    [(add l r) (num+ (interp l env) (interp r env))]
    [(if0 c t f)
     (if (num-zero? (interp c env))
         (interp t env)
         (interp f env))]
    [(id x) (env-lookup x env)]
    [(printn e) 
      (def (numV n) (interp e env))
      ((print-par) n)
      ;;(println-g n) ;;primer intento
      (numV n)]
    [(app fun-expr arg-expr)
     (match (interp fun-expr env)
       [(closV id body fenv)
        (interp body
                (extend-env id
                            (interp arg-expr env)
                            fenv))])]))

(define (num+ n1 n2)
  (numV (+ (numV-n n1) (numV-n n2))))
 
(define (num-zero? n)
  (zero? (numV-n n)))
 
;; interp-top :: CL -> number
;; interpreta una expresión y retorna el valor final
(define (interp-top expr)
  (match (interp expr empty-env)
    [(numV n) n]
    [_ 'procedure]))
    
;; run-cl :: s-expr -> number
(define (run-cl prog)
  (interp-top (parse-cl prog)))

;; tests
(test (run-cl '{with {addn {fun {n}
                          {fun {m}
                            {+ n m}}}}
                 {{addn 10} 4}})
      14)

;; AGREGADO :

;; interp-g :: expr -> Result
;; retorna un valor de tipo Result (usando interp) pero reiniciando en cada llamada el log global.
(define (interp-g expr)
  (set-box! log '())
  (define v (interp expr empty-env))
  (result v log))

;; interp-p :: expr -> Result
;; retorna un valor de tipo Result (usando interp) haciendo uso de interp, pero manteniendo un
;; log local y redefiniendo el valor del parámetro. El nuevo valor del parámetro debe ser una
;; función que registre impresiones en el log local.
(define (interp-p expr)
  (def log-local (box '()))
  (parameterize ([print-par (register log-local)])
    (define v (interp expr empty-env))
    (result v log-local)))





