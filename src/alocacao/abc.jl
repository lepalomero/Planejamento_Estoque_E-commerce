using Dates
using Random

abstract type MetodoAlocacao end

struct MetodoABC <: MetodoAlocacao end

mutable struct MetodoAleatorio <: MetodoAlocacao
    rng::MersenneTwister
end

MetodoAleatorio(semente::Integer=7) = MetodoAleatorio(MersenneTwister(semente))

struct MetodoCoocorrencia <: MetodoAlocacao
    skus::Vector{String}
    indice_por_sku::Dict{String,Int}
    pares::Dict{UInt64,Int}
    adjacencias::Vector{Vector{Int}}
    graus::Vector{Int}
end

_nome_metodo(::MetodoABC) = "abc_sku"
_nome_metodo(::MetodoAleatorio) = "random"
_nome_metodo(::MetodoCoocorrencia) = "coocorrencia"
_pasta_saida_metodo(pasta_base, metodo::MetodoAlocacao) =
    joinpath(pasta_base, _nome_metodo(metodo))

function _sufixar_arquivo(nome, sufixo_metodo)
    isempty(sufixo_metodo) && return nome
    base, extensao = splitext(nome)
    return "$(base)_$(sufixo_metodo)$(extensao)"
end

function _chave_par(i::Int, j::Int)
    menor, maior = minmax(UInt32(i), UInt32(j))
    return (UInt64(menor) << 32) | UInt64(maior)
end

function MetodoCoocorrencia(previsoes, coluna::Symbol)
    skus = sort!(String[string(sku) for sku in keys(previsoes)])
    indice_por_sku = Dict(sku => indice for (indice, sku) in enumerate(skus))
    semanas_por_sku = Dict{Date,Set{Int}}()

    for (sku_original, semanas) in previsoes
        sku = string(sku_original)
        indice = indice_por_sku[sku]
        for semana in semanas
            demanda = getproperty(semana, coluna)
            demanda isa Real && isfinite(demanda) && demanda >= 0 ||
                throw(ArgumentError("Previsao invalida para o item $(sku)"))
            if demanda > 0
                itens_semana = get!(semanas_por_sku, semana.semana) do
                    Set{Int}()
                end
                push!(itens_semana, indice)
            end
        end
    end

    pares = Dict{UInt64,Int}()
    adjacencias = [Int[] for _ in skus]
    graus = zeros(Int, length(skus))
    for indices_semana in values(semanas_por_sku)
        indices = sort!(collect(indices_semana))
        for i in 1:(length(indices) - 1), j in (i + 1):length(indices)
            sku_i, sku_j = indices[i], indices[j]
            chave = _chave_par(sku_i, sku_j)
            ocorrencias = get(pares, chave, 0)
            if ocorrencias == 0
                push!(adjacencias[sku_i], sku_j)
                push!(adjacencias[sku_j], sku_i)
            end
            pares[chave] = ocorrencias + 1
            graus[sku_i] += 1
            graus[sku_j] += 1
        end
    end

    return MetodoCoocorrencia(skus, indice_por_sku, pares, adjacencias, graus)
end

function _coocorrencia(metodo::MetodoCoocorrencia, sku_a, sku_b)
    sku_a == sku_b && return 0
    indice_a = get(metodo.indice_por_sku, sku_a, 0)
    indice_b = get(metodo.indice_por_sku, sku_b, 0)
    (indice_a == 0 || indice_b == 0) && return 0
    return get(metodo.pares, _chave_par(indice_a, indice_b), 0)
end

function _classes_abc(estoque, percentuais)
    ordenados = sort(collect(estoque); by=item -> (-item.frequencia_pedidos, item.id))
    total = sum(item.frequencia_pedidos for item in ordenados)
    classes = Dict{String,Symbol}()
    acumulado = 0
    limites = cumsum(percentuais) ./ 100

    for item in ordenados
        proporcao_anterior = total == 0 ? 1.0 : acumulado / total
        classe =
            proporcao_anterior < limites[1] ? :A :
            proporcao_anterior < limites[2] ? :B : :C
        classes[item.id] = classe
        acumulado += item.frequencia_pedidos
    end
    return classes
end

function _itens_ordenados(estoque, percentuais, ::MetodoABC)
    classes = _classes_abc(estoque, percentuais)
    ordem_classe = Dict(:A => 1, :B => 2, :C => 3)
    return sort(
        collect(estoque);
        by=item -> (ordem_classe[classes[item.id]], -item.frequencia_pedidos, item.id),
    )
end

_itens_ordenados(estoque, _, metodo::MetodoAleatorio) =
    shuffle(metodo.rng, collect(estoque))

function _itens_ordenados(estoque, _, metodo::MetodoCoocorrencia)
    itens = collect(estoque)
    itens_por_indice = Dict{Int,eltype(itens)}()
    itens_sem_previsao = eltype(itens)[]
    for item in itens
        indice = get(metodo.indice_por_sku, item.id, 0)
        if indice == 0
            push!(itens_sem_previsao, item)
        else
            itens_por_indice[indice] = item
        end
    end

    sementes = sort!(
        collect(keys(itens_por_indice));
        by=indice -> (
            -metodo.graus[indice],
            -itens_por_indice[indice].frequencia_pedidos,
            metodo.skus[indice],
        ),
    )
    restantes = Set(sementes)
    indices_ordenados = Int[]
    for semente in sementes
        semente in restantes || continue
        atual = semente
        while atual != 0
            delete!(restantes, atual)
            push!(indices_ordenados, atual)

            melhor_vizinho = 0
            melhor_chave = nothing
            for vizinho in metodo.adjacencias[atual]
                vizinho in restantes || continue
                chave = (
                    -_coocorrencia(metodo, metodo.skus[atual], metodo.skus[vizinho]),
                    -metodo.graus[vizinho],
                    -itens_por_indice[vizinho].frequencia_pedidos,
                    metodo.skus[vizinho],
                )
                if melhor_chave === nothing || isless(chave, melhor_chave)
                    melhor_vizinho = vizinho
                    melhor_chave = chave
                end
            end
            atual = melhor_vizinho
        end
    end

    sort!(itens_sem_previsao; by=item -> (-item.frequencia_pedidos, item.id))
    return vcat(
        [itens_por_indice[indice] for indice in indices_ordenados],
        itens_sem_previsao,
    )
end
