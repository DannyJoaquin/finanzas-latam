import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../users/user.entity';
import { Expense } from '../expenses/expense.entity';

export enum CategoryType {
  EXPENSE = 'expense',
  INCOME = 'income',
}

@Index('idx_categories_user_type', ['user', 'type'])
@Index('idx_categories_parent', ['parent'])
@Entity('categories')
export class Category {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', nullable: true })
  userId: string;

  @ManyToOne(() => User, (user) => user.categories, { nullable: true })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'parent_id', nullable: true })
  parentId: string;

  @ManyToOne(() => Category, (cat) => cat.children, { nullable: true })
  @JoinColumn({ name: 'parent_id' })
  parent: Category;

  @OneToMany(() => Category, (cat) => cat.parent)
  children: Category[];

  @Column({ length: 100 })
  name: string;

  @Column({ length: 50, nullable: true })
  icon: string;

  @Column({ type: 'char', length: 7, nullable: true })
  color: string;

  @Column({ type: 'enum', enum: CategoryType })
  type: CategoryType;

  @Column({ name: 'is_system', default: false })
  isSystem: boolean;

  @Column({ name: 'sort_order', type: 'smallint', default: 0 })
  sortOrder: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @OneToMany(() => Expense, (e) => e.category)
  expenses: Expense[];
}
