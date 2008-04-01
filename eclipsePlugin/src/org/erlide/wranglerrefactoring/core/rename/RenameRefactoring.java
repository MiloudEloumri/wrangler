package org.erlide.wranglerrefactoring.core.rename;

import org.erlide.jinterface.rpc.RpcException;
import org.erlide.runtime.backend.RpcResult;
import org.erlide.runtime.backend.exceptions.ErlangRpcException;
import org.erlide.wranglerrefactoring.core.RefactoringParameters;
import org.erlide.wranglerrefactoring.core.WranglerRefactoring;

import com.ericsson.otp.erlang.OtpErlangList;

public abstract class RenameRefactoring extends WranglerRefactoring {

	public RenameRefactoring(RefactoringParameters parameters) {
		super(parameters);
	}

	@Override
	public abstract String getName();

	@Override
	protected abstract RpcResult sendRPC(String filePath,
			OtpErlangList searchPath) throws ErlangRpcException, RpcException;

}
