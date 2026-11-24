abstract type MetodoAlocacao end

struct MetodoABC <: MetodoAlocacao end

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
