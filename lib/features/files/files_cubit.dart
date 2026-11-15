import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/failure.dart';
import '../transfers/models/remote_file.dart';
import 'files_repository.dart';

class FilesState extends Equatable {
  const FilesState({this.files = const [], this.loading = false, this.error});

  final List<RemoteFile> files;
  final bool loading;
  final String? error;

  @override
  List<Object?> get props => [files, loading, error];
}

class FilesCubit extends Cubit<FilesState> {
  FilesCubit(this._repo) : super(const FilesState());

  final FilesRepository _repo;

  Future<void> load() async {
    emit(FilesState(files: state.files, loading: true));
    try {
      emit(FilesState(files: await _repo.list()));
    } catch (e) {
      emit(FilesState(files: state.files, error: Failure.from(e).message));
    }
  }


  Future<String?> delete(RemoteFile file) async {
    try {
      await _repo.delete(file.name);
      emit(FilesState(files: state.files.where((f) => f.name != file.name).toList()));
      return null;
    } catch (e) {
      return Failure.from(e).message;
    }
  }
}
