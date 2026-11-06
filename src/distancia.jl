
function distancia_estantes(estante1::estante, estante2::estante, largura_armazem, comprimento_armazem)
        distancia=0
        if estante1.posicao[1]==estante2.posicao[1]
            if estante1.posicao[2]<0 && estante2.posicao[2]<0 || estante1.posicao[2]>0 && estante2.posicao[2]>0
                distancia= abs(estante1.posicao[2]- estante2.posicao[2])
            else
                distancia= abs(estante1.posicao[2])+ abs(estante2.posicao[2])
            end
            return distancia
        
        distancia_esq=0
        
        #indo primeiro pela esquerda
        elseif estante1.posicao[1]>0
            distancia_esq+= estante1.posicao[1]
            if estante2.posicao[2] > estante1.posicao[2]
                distancia_esq+= estante2.posicao[2] - estante1.posicao[2]
            else
                distancia_esq+= estante1.posicao[2]- estante2.posicao[2]
            end 
            distancia_esq+= abs(estante2.posicao[1])
        else 
            distancia_esq+= (comprimento_armazem/2) + estante1.posicao[1]
            if estante2.posicao[2] > estante1.posicao[2]
                distancia_esq+= estante2.posicao[2] - estante1.posicao[2]
            else
                distancia_esq+= estante1.posicao[2]- estante2.posicao[2]
            end 
            if estante2.posicao[1]>0
                distancia_esq+= estante2.posicao[1]+ (comprimento_armazem/2)
            else
                distancia_esq+= (comprimento_armazem/2)- estante2.posicao[1]
            end
            
        end

        #indo pela direita
        distancia_dir=0
        if estante1.posicao[1]>0
            distancia_dir+= (comprimento_armazem/2)- estante1.posicao[1]
            if estante2.posicao[2] > estante1.posicao[2]
                distancia_dir+= estante2.posicao[2] - estante1.posicao[2]
            else
                distancia_dir+= estante1.posicao[2]- estante2.posicao[2]
            end 
            if estante2.posicao[1]<0
                distancia_dir+= abs(estante2.posicao[1])+ (comprimento_armazem/2)
            else
                distancia_dir+= (comprimento_armazem/2)- estante2.posicao[1]
            end
            
        else 
            distancia_dir+= (comprimento_armazem/2) + estante1.posicao[1]
            if estante2.posicao[2] > estante1.posicao[2]
                distancia_dir+= estante2.posicao[2] - estante1.posicao[2]
            else
                distancia_dir+= estante1.posicao[2]- estante2.posicao[2]
            end 
            distancia_dir+= abs(estante2.posicao[1])
            
        end

        return max(distancia_dir, distancia_esq)
end