using Random

function roteamento(armazem::armazem, n_caminhoes, produtos_por_caminhao, caminhoes_por_dia,
                    localizacao::Dict{String,Int};
                    n_iteracoes::Int = 200, k::Int = 1, rng = Random.default_rng())

    estantes = armazem.lista_estantes
    L, C = armazem.largura_armazem, armazem.comprimento_armazem

    # (dia, posição no dia) de cada caminhão
    ident = [(dia, j) for dia in sort(collect(keys(caminhoes_por_dia)))
                      for j in eachindex(caminhoes_por_dia[dia])]

    resultados = NamedTuple[]
    distancia_total = 0.0

    for i in 1:n_caminhoes
        # 1. estantes a visitar (uma estante = um produto)
        ids = unique(produtos_por_caminhao[i])
        sem_local = filter(id -> !haskey(localizacao, id), ids)
        isempty(sem_local) || @warn "Produtos sem estante, ignorados" caminhao=i sem_local
        paradas = unique(localizacao[id] for id in ids if haskey(localizacao, id))
        m = length(paradas)
        m == 0 && continue

        # 2. matriz de distâncias
        D = zeros(m, m)
        for a in 1:m, b in 1:m
            a == b && continue
            D[a, b] = distancia_estantes(estantes[paradas[a]], estantes[paradas[b]], L, C)
        end

        # 3. várias rotas: início aleatório + vizinho mais próximo
        melhor_rota, melhor_dist = Int[], Inf
        for _ in 1:n_iteracoes
            atual  = rand(rng, 1:m)
            rota   = [atual]
            livres = Set(1:m); delete!(livres, atual)
            dist   = 0.0

            while !isempty(livres)
                cand = sort!(collect(livres), by = j -> D[atual, j])
                prox = cand[rand(rng, 1:min(k, length(cand)))]
                dist += D[atual, prox]
                push!(rota, prox); delete!(livres, prox)
                atual = prox
            end

            if dist < melhor_dist
                melhor_dist, melhor_rota = dist, rota
            end
        end

        # 4. rota final: estantes (= produtos) na ordem do percurso
        rota_estantes = paradas[melhor_rota]

        dia, j = ident[i]
        append!(caminhoes_por_dia[dia][j].rota_produtos, rota_estantes)

        push!(resultados, (caminhao = i, dia = dia,
                           rota = rota_estantes,
                           distancia = melhor_dist))
        distancia_total += melhor_dist
    end

    return resultados, distancia_total
end