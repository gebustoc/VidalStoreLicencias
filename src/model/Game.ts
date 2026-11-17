import { Column, Entity, PrimaryGeneratedColumn, Unique } from "typeorm"

@Entity()
export class Game{
    @PrimaryGeneratedColumn()
    id:number= 0

    @Column({unique:true})
    slug:string= ""

    @Column()
    name:string= ""

    @Column()
    lowercasename:string= ""

    @Column()
    released:string= "2018-10-26"

    @Column()
    background_image:string= ""

    @Column()
    saturated_color:string= ""

    @Column()
    dominant_color:string= ""
}
