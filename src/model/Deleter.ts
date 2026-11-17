import { License } from "./License.js"
import { Column, Entity, JoinColumn, OneToOne, PrimaryGeneratedColumn } from "typeorm"

@Entity()
export class Deleter {


    @PrimaryGeneratedColumn()
    id:number=0

    @Column()
    deleterUid:string

    @Column()
    ownerUid:string

    gameID:number

    constructor(deleter?:string,license?:License){
      if (deleter && license) {
        this.deleterUid = deleter
        this.ownerUid = license.uid
        this.gameID = license.game.id
      }
    }

}
