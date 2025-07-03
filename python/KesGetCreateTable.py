#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# @Time : 2025年7月2日 22:20:59
# @Author : raysuen
# @version 2.0

import psycopg2
import sys
import argparse
from getpass import getpass
import re
import traceback

def quote_identifier(identifier):
    """正确引用标识符，处理大小写和特殊字符"""
    if not re.match(r'^[a-z_][a-z0-9_]*$', identifier):
        return f'"{identifier}"'
    return identifier

class TableMetadataFetcher:
    """负责从数据库获取表元数据的类"""
    
    def __init__(self, conn, schema):
        self.conn = conn
        self.schema = schema
        self.metadata = {}
    
    def fetch_enum_types(self):
        """获取数据库中所有枚举类型及其值"""
        with self.conn.cursor() as cur:
            cur.execute("""
                SELECT t.typname, array_agg(e.enumlabel ORDER BY e.enumsortorder)
                FROM sys_type t
                JOIN sys_enum e ON t.oid = e.enumtypid
                JOIN sys_namespace n ON n.oid = t.typnamespace
                GROUP BY t.typname, n.nspname
            """)
            return {row[0]: row[1] for row in cur.fetchall()}
    
    def fetch_all_table_names(self):
        """获取模式下的所有表名"""
        with self.conn.cursor() as cur:
            cur.execute(f"""
                SELECT c.relname
                FROM sys_class c
                JOIN sys_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = '{self.schema}'
                  AND c.relkind = 'r'  -- 只获取普通表
                ORDER BY c.relname;
            """)
            return [row[0] for row in cur.fetchall()]
    
    def fetch_table_metadata(self, table_name, include_views=False):
        """获取单个表的完整元数据"""
        enum_types = self.fetch_enum_types()
        metadata = {
            'table': table_name,
            'columns': [],
            'pk_constraint': None,
            'indexes': [],
            'table_comment': None,
            'enum_types': enum_types,
            'is_view': False
        }
        
        with self.conn.cursor() as cur:
            # 确定是表还是视图
            cur.execute(f"""
                SELECT c.relkind
                FROM sys_class c
                JOIN sys_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = '{self.schema}' 
                  AND c.relname = '{table_name}'
            """)
            result = cur.fetchone()
            
            if not result:
                raise ValueError(f"表/视图 {self.schema}.{table_name} 不存在")
            
            relkind = result[0]
            metadata['is_view'] = (relkind == 'v')
            
            # 获取列定义
            if metadata['is_view']:
                # 视图处理
                if not include_views:
                    raise ValueError(f"跳过视图: {self.schema}.{table_name} (使用 --include-views 包含视图)")
                
                cur.execute(f"""
                    SELECT 
                        a.attname,
                        format_type(a.atttypid, a.atttypmod) AS type,
                        true AS nullable,  -- 视图列默认可为空
                        NULL AS default_value,
                        t.typname AS base_type,
                        '' AS attgenerated,
                        NULL AS generated_expr,
                        (SELECT description 
                         FROM sys_description 
                         WHERE objoid = a.attrelid AND objsubid = a.attnum) AS comment
                    FROM sys_attribute a
                    JOIN sys_class c ON a.attrelid = c.oid
                    JOIN sys_namespace n ON n.oid = c.relnamespace
                    JOIN sys_type t ON a.atttypid = t.oid
                    WHERE n.nspname = '{self.schema}' 
                      AND c.relname = '{table_name}'
                      AND a.attnum > 0
                      AND NOT a.attisdropped
                    ORDER BY a.attnum;
                """)
            else:
                # 表处理
                cur.execute(f"""
                    SELECT 
                        a.attname,
                        format_type(a.atttypid, a.atttypmod) AS type,
                        NOT a.attnotnull AS nullable,
                        pg_get_expr(d.adbin, d.adrelid) AS default_value,
                        t.typname AS base_type,
                        a.attgenerated,
                        pg_get_expr(d.adbin, d.adrelid) AS generated_expr,
                        (SELECT description 
                         FROM sys_description 
                         WHERE objoid = a.attrelid AND objsubid = a.attnum) AS comment
                    FROM sys_attribute a
                    JOIN sys_class c ON a.attrelid = c.oid
                    JOIN sys_namespace n ON n.oid = c.relnamespace
                    JOIN sys_type t ON a.atttypid = t.oid
                    LEFT JOIN sys_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
                    WHERE n.nspname = '{self.schema}' 
                      AND c.relname = '{table_name}'
                      AND a.attnum > 0
                      AND NOT a.attisdropped
                    ORDER BY a.attnum;
                """)
            
            metadata['columns'] = cur.fetchall()
            
            if not metadata['columns']:
                raise ValueError(f"表/视图 {self.schema}.{table_name} 没有列")
            
            # 如果不是视图，获取约束和索引
            if not metadata['is_view']:
                # 获取主键约束
                cur.execute(f"""
                    SELECT con.conname, array_agg(a.attname ORDER BY pos.n)
                    FROM sys_constraint con
                    JOIN sys_class c ON con.conrelid = c.oid
                    JOIN sys_namespace n ON n.oid = c.relnamespace
                    JOIN LATERAL unnest(con.conkey) WITH ORDINALITY pos(k, n) ON true
                    JOIN sys_attribute a ON a.attnum = pos.k AND a.attrelid = c.oid
                    WHERE n.nspname = '{self.schema}'
                      AND c.relname = '{table_name}'
                      AND con.contype = 'p'
                    GROUP BY con.conname
                """)
                metadata['pk_constraint'] = cur.fetchone()
                
                # 获取索引
                cur.execute(f"""
                    SELECT
                        idx.relname AS index_name,
                        am.amname AS index_type,
                        array_agg(a.attname ORDER BY pos.n) AS columns,
                        pg_get_indexdef(i.indexrelid) AS index_def
                    FROM sys_index i
                    JOIN sys_class idx ON idx.oid = i.indexrelid
                    JOIN sys_am am ON am.oid = idx.relam
                    JOIN sys_class tbl ON tbl.oid = i.indrelid
                    JOIN sys_namespace n ON n.oid = tbl.relnamespace
                    JOIN LATERAL unnest(i.indkey) WITH ORDINALITY pos(k, n) ON true
                    JOIN sys_attribute a ON a.attnum = pos.k AND a.attrelid = tbl.oid
                    WHERE n.nspname = '{self.schema}'
                      AND tbl.relname = '{table_name}'
                      AND i.indisprimary = false
                    GROUP BY idx.relname, am.amname, i.indexrelid
                """)
                metadata['indexes'] = cur.fetchall()
            
            # 获取表/视图注释
            cur.execute(f"""
                SELECT description
                FROM sys_description
                WHERE objoid = (
                    SELECT c.oid 
                    FROM sys_class c
                    JOIN sys_namespace n ON n.oid = c.relnamespace
                    WHERE n.nspname = '{self.schema}' AND c.relname = '{table_name}'
                ) AND objsubid = 0
            """)
            result = cur.fetchone()
            metadata['table_comment'] = result[0] if result else None
        
        return metadata

class DDLGenerator:
    """负责根据元数据生成DDL语句的类"""
    
    def __init__(self, metadata, schema):
        self.metadata = metadata
        self.schema = schema
    
    def generate_ddl(self):
        """生成完整的DDL语句"""
        ddl_lines = []
        table_name = self.metadata['table']
        
        if self.metadata['is_view']:
            # 视图处理 - 简化输出
            ddl_lines.extend(self._generate_view_definition())
        else:
            # 表处理
            ddl_lines.extend(self._generate_create_table())
            
            # 生成表注释
            if self.metadata['table_comment']:
                ddl_lines.append(self._generate_table_comment())
            
            # 生成列注释
            ddl_lines.extend(self._generate_column_comments())
            
            # 生成索引
            ddl_lines.extend(self._generate_indexes())
        
        # 添加分隔符
        ddl_lines.append("\n--" + "-" * 78 + "\n")
        
        return "\n".join(ddl_lines)
    
    def _generate_create_table(self):
        """生成CREATE TABLE语句部分"""
        quoted_schema = quote_identifier(self.schema)
        quoted_table = quote_identifier(self.metadata['table'])
        ddl_lines = [f"CREATE TABLE {quoted_schema}.{quoted_table} ("]
        
        table_elements = []
        column_comments = []
        
        # 处理列定义
        for col in self.metadata['columns']:
            name, data_type, nullable, default_value, base_type, generated, generated_expr, comment = col
            quoted_name = quote_identifier(name)
            
            # 处理虚拟列
            if generated != '':
                generated_type = "STORED" if generated == 's' else "VIRTUAL"
                col_def = f"    {quoted_name} {data_type} GENERATED ALWAYS AS ({generated_expr}) {generated_type}"
            else:
                # 处理特殊数据类型
                if base_type in self.metadata['enum_types']:
                    enum_values = ", ".join(f"'{v}'" for v in self.metadata['enum_types'][base_type])
                    col_def = f"    {quoted_name} {data_type} CHECK ({quoted_name} IN ({enum_values}))"
                elif data_type.startswith('geometry'):
                    col_def = f"    {quoted_name} {data_type}"
                else:
                    col_def = f"    {quoted_name} {data_type}"
                
                # 处理默认值
                if default_value and not default_value.startswith("nextval"):
                    default_value = re.sub(r'::\w+[\w\s]*$', '', default_value)
                    col_def += f" DEFAULT {default_value}"
            
            # 处理NULL约束
            if not nullable and generated == '':
                col_def += " NOT NULL"
            
            table_elements.append(col_def)
            
            # 保存列注释
            if comment:
                escaped_comment = comment.replace("'", "''")
                quoted_schema = quote_identifier(self.schema)
                quoted_table = quote_identifier(self.metadata['table'])
                quoted_name = quote_identifier(name)
                column_comments.append(
                    f"COMMENT ON COLUMN {quoted_schema}.{quoted_table}.{quoted_name} IS '{escaped_comment}';"
                )
        
        # 保存列注释到元数据
        self.metadata['column_comments'] = column_comments
        
        # 添加主键约束
        if self.metadata['pk_constraint']:
            pk_name, pk_cols = self.metadata['pk_constraint']
            quoted_pk_name = quote_identifier(pk_name)
            quoted_pk_cols = ", ".join(quote_identifier(col) for col in pk_cols)
            table_elements.append(f"    CONSTRAINT {quoted_pk_name} PRIMARY KEY ({quoted_pk_cols})")
        
        ddl_lines.append(",\n".join(table_elements))
        ddl_lines.append(");")
        
        return ddl_lines
    
    def _generate_view_definition(self):
        """生成视图定义"""
        quoted_schema = quote_identifier(self.schema)
        quoted_table = quote_identifier(self.metadata['table'])
        ddl_lines = [f"-- 视图: {quoted_schema}.{quoted_table}"]
        
        # 添加列信息
        ddl_lines.append("-- 列定义:")
        for col in self.metadata['columns']:
            name, data_type, _, _, _, _, _, _ = col
            quoted_name = quote_identifier(name)
            ddl_lines.append(f"--   {quoted_name}: {data_type}")
        
        # 添加视图注释
        if self.metadata['table_comment']:
            escaped_comment = self.metadata['table_comment'].replace("'", "''")
            ddl_lines.append(f"\nCOMMENT ON VIEW {quoted_schema}.{quoted_table} IS '{escaped_comment}';")
        
        return ddl_lines
    
    def _generate_table_comment(self):
        """生成表注释语句"""
        quoted_schema = quote_identifier(self.schema)
        quoted_table = quote_identifier(self.metadata['table'])
        escaped_comment = self.metadata['table_comment'].replace("'", "''")
        return f"\nCOMMENT ON TABLE {quoted_schema}.{quoted_table} IS '{escaped_comment}';"
    
    def _generate_column_comments(self):
        """生成列注释语句"""
        return self.metadata.get('column_comments', [])
    
    def _generate_indexes(self):
        """生成索引语句"""
        index_lines = []
        for index in self.metadata['indexes']:
            _, _, _, idx_def = index
            index_lines.append(f"\n{idx_def};")
        return index_lines

def main():
    parser = argparse.ArgumentParser(
        description='Kingbase 数据库结构导出工具',
        formatter_class=argparse.RawTextHelpFormatter,
        epilog="示例:\n"
               "  导出单个表:  KesGetDDL.py -H localhost -d mydb -U admin -s public -t orders\n"
               "  导出整个模式: KesGetDDL.py -H localhost -d mydb -U admin -s public\n"
               "  包含视图:    KesGetDDL.py -H localhost -d mydb -U admin -s public --include-views"
    )
    parser.add_argument('-H', '--host', default='localhost', help='数据库主机 (默认: localhost)')
    parser.add_argument('-p', '--port', default=54321, type=int, help='数据库端口 (默认: 54321)')
    parser.add_argument('-d', '--dbname', required=True, help='数据库名 (必需)')
    parser.add_argument('-U', '--user', required=True, help='用户名 (必需)')
    parser.add_argument('-W', '--password', help='密码 (可选，若不提供将提示输入)')
    parser.add_argument('-s', '--schema', default='public', help='模式名 (默认: public)')
    parser.add_argument('-t', '--table', help='表名 (可选，不指定则导出整个模式)')
    parser.add_argument('--include-views', action='store_true', help='包含视图 (默认只导出表)')
    parser.add_argument('-o', '--output', help='输出到文件 (可选)')
    
    args = parser.parse_args()
    
    # 获取密码
    password = args.password or getpass("请输入密码: ")
    
    conn = None
    output_file = None
    try:
        # 连接数据库
        conn = psycopg2.connect(
            host=args.host,
            port=args.port,
            dbname=args.dbname,
            user=args.user,
            password=password
        )
        
        # 设置输出
        if args.output:
            output_file = open(args.output, 'w', encoding='utf-8')
            output = output_file
        else:
            output = sys.stdout
        
        # 打印标题
        title = f"-- Kingbase 数据库结构导出\n"
        title += f"-- 主机: {args.host}:{args.port}\n"
        title += f"-- 数据库: {args.dbname}\n"
        title += f"-- 模式: {args.schema}\n"
        title += f"-- 时间: {args.Time if hasattr(args, 'Time') else 'N/A'}\n"
        title += "--" * 40 + "\n\n"
        output.write(title)
        
        # 获取元数据获取器
        fetcher = TableMetadataFetcher(conn, args.schema)
        
        # 确定要处理的表列表
        if args.table:
            table_names = [args.table]
        else:
            table_names = fetcher.fetch_all_table_names()
            output.write(f"-- 导出整个模式，共 {len(table_names)} 张表\n\n")
        
        # 处理每个表
        for table_name in table_names:
            try:
                # 获取表元数据
                metadata = fetcher.fetch_table_metadata(table_name, args.include_views)
                
                # 生成DDL
                generator = DDLGenerator(metadata, args.schema)
                ddl = generator.generate_ddl()
                
                output.write(f"-- 表: {args.schema}.{table_name}\n")
                output.write(ddl + "\n")
                
            except ValueError as e:
                output.write(f"-- 错误: {str(e)}\n\n")
                continue
            except Exception as e:
                output.write(f"-- 处理表 {table_name} 时出错: {str(e)}\n")
                traceback.print_exc(file=output)
                output.write("\n")
                continue
        
        # 添加结束标记
        output.write("\n-- 导出完成\n")
        
    except psycopg2.OperationalError as e:
        print(f"数据库连接错误: {e}")
        sys.exit(1)
    except psycopg2.Error as e:
        print(f"数据库查询错误: {e.pgerror}")
        sys.exit(1)
    except Exception as e:
        print(f"未预期的错误: {str(e)}")
        traceback.print_exc()
        sys.exit(1)
    finally:
        if conn:
            conn.close()
        if output_file:
            output_file.close()

if __name__ == "__main__":
    main()