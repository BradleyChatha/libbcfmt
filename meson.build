project('libbcfmt', 'd')

libbcds_dep = subproject('libbcds').get_variable('libbcds_dep')

src = [
    'source/libbc/fmt/fmt.d',
    'source/libbc/fmt/conv.d',
    'source/libbc/fmt/package.d'
]

include = include_directories('source/')

libbcfmt = static_library('bcfmt', src, include_directories: include, dependencies: libbcds_dep, d_args: '-betterC')
libbcfmt_test = executable(
    'bcfmt_test', 
    src, 
    'source/test.d', 
    include_directories: include, 
    dependencies: libbcds_dep, 
    d_args: ['-betterC', '-unittest']
)

libbcfmt_dep = declare_dependency(sources: src, include_directories: include, dependencies: libbcds_dep)

test('bcfmt', libbcfmt_test)