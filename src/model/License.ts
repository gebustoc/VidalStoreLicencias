import { randomUUID, UUID } from "crypto"
import { Column, Entity, JoinColumn, ManyToOne, OneToMany, PrimaryGeneratedColumn } from "typeorm"
import { Game } from "./Game.js"

@Entity()
export class License {
    @PrimaryGeneratedColumn()
    id:number=0
    @Column()
    uid:string=""
    
    @ManyToOne(() => Game)
    @JoinColumn()
    game:Game
    

    constructor(uid:string=randomUUID(),id:number=0,game:Game){
        this.uid = uid
        this.id = id
        this.game = game
    }

}