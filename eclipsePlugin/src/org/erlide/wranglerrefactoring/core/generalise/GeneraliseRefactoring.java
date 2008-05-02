package org.erlide.wranglerrefactoring.core.generalise;

import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.core.runtime.OperationCanceledException;
import org.eclipse.ltk.core.refactoring.RefactoringStatus;
import org.eclipse.ltk.core.refactoring.RefactoringStatusEntry;
import org.erlide.jinterface.rpc.RpcException;
import org.erlide.runtime.backend.RpcResult;
import org.erlide.runtime.backend.exceptions.ErlangRpcException;
import org.erlide.wranglerrefactoring.core.RefactoringParameters;
import org.erlide.wranglerrefactoring.core.WranglerRefactoring;
import org.erlide.wranglerrefactoring.core.exception.WranglerException;

import com.ericsson.otp.erlang.OtpErlangBoolean;
import com.ericsson.otp.erlang.OtpErlangList;
import com.ericsson.otp.erlang.OtpErlangObject;
import com.ericsson.otp.erlang.OtpErlangTuple;

public class GeneraliseRefactoring extends WranglerRefactoring {

	protected OtpErlangObject parName;
	protected OtpErlangObject funName;
	protected OtpErlangObject arity;
	protected OtpErlangObject defPos;
	protected OtpErlangObject expression;

	protected boolean hasSideEffect;

	RefactoringStatus refactoringStatus = new RefactoringStatus();

	public GeneraliseRefactoring(RefactoringParameters parameters) {
		super(parameters);
	}

	public void setSideEffect(boolean b) {
		hasSideEffect = b;
	}

	public void setAdditionalParameters(OtpErlangObject parName,
			OtpErlangObject funName, OtpErlangObject arity,
			OtpErlangObject defPos, OtpErlangObject expression) {
		this.parName = parName;
		this.funName = funName;
		this.arity = arity;
		this.defPos = defPos;
		this.expression = expression;
	}

	public void addRefactoringStatus(RefactoringStatus rs) {
		for (RefactoringStatusEntry rse : rs.getEntries()) {
			refactoringStatus.addEntry(rse);
		}
	}

	@Override
	public RefactoringStatus checkFinalConditions(IProgressMonitor pm)
			throws OperationCanceledException, CoreException {
		// RefactoringStatus rs = super.checkFinalConditions(pm);

		// for (RefactoringStatusEntry rse : rs.getEntries()) {
		// refactoringStatus.addEntry(rse);
		// }

		return refactoringStatus;
	}

	@Override
	public String getName() {
		return "Generalise function";
	}

	@Override
	protected RpcResult sendRPC(String filePath, OtpErlangList searchPath)
			throws ErlangRpcException, RpcException {
		// TODO: generalise into parameters!!!
		OtpErlangTuple startPos = createPos(parameters.getStartLine(),
				parameters.getStartColoumn());
		OtpErlangTuple endPos = createPos(parameters.getEndLine(), parameters
				.getEndColoumn());
		return managedBackend.rpc("wrangler", "generalise_eclipse", "sxxsx",
				filePath, startPos, endPos, newName, searchPath);
	}

	@Override
	protected GeneraliseRPCMessage convertToMessage(RpcResult r)
			throws WranglerException {
		GeneraliseRPCMessage m = new GeneraliseRPCMessage(r, this);
		m.checkIsOK();
		return m;
	}

	public GeneraliseRPCMessage callGenerealise() throws ErlangRpcException,
			RpcException, WranglerException {
		RpcResult res = sendRPC(parameters.getFilePath(), parameters
				.getProject());
		return convertToMessage(res);
	}

	public GeneraliseRPCMessage callGeneralise1() throws RpcException,
			WranglerException {
		OtpErlangBoolean b = new OtpErlangBoolean(this.hasSideEffect);
		RpcResult r = managedBackend.rpc("wrangler", "gen_fun_1_eclipse",
				"xsxxxxx", b, parameters.getFilePath(), this.parName,
				this.funName, this.arity, this.defPos, this.expression);
		return convertToMessage(r);

	}

	public GeneraliseRPCMessage callGeneralise2() throws RpcException,
			WranglerException {
		RpcResult r = managedBackend.rpc("wrangler", "gen_fun_2_eclipse",
				"sxxxxxx", parameters.getFilePath(), this.parName,
				this.funName, this.arity, this.defPos, this.expression,
				parameters.getProject());
		return convertToMessage(r);
	}

}
